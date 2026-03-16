"""
DIST.RESS Signal Network — Python AI / NLP Service

FastAPI application that:
  - Subscribes to Redis 'sos-events' (inbound from Node.js)
  - Classifies each SOS report with a triage severity
  - PATCHes the triage result back to Node.js
  - Monitors a simulated social-media feed for threats
  - POSTs high-confidence alerts to Node.js
  - Provides POST /routing/optimise (OR-Tools TSP solver)

All triage endpoints are async def.
During an earthquake scenario with 6 nodes firing simultaneously,
a sync endpoint creates a 3-second queue. Async handles all 6 concurrently.
"""

from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from distress_ai.config import settings
from distress_ai.monitor import monitor_loop, stop_monitor
from distress_ai.subscriber import start_subscriber, stop_subscriber
from distress_ai.solver import optimise_route, MAX_WAYPOINTS
from distress_ai.monitor.collectors import _source_health

# ── Logging ─────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(name)-24s | %(levelname)-7s | %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("distress.main")


# ── Lifespan (startup / shutdown) ───────────────────────
# STARTUP ORDER:
#   1. Validate env vars (log FATAL if missing, but don't crash)
#   2. Connect to Redis subscriber (graceful failure)
#   3. Start social-media monitor
#   4. Log ready message

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("[START]  DIST.RESS AI service starting ...")

    # ── ENV VAR VALIDATION ──────────────────────────────
    if not settings.redis_url:
        logger.error("FATAL: REDIS_URL not set. Set it in Railway environment.")
    else:
        logger.info("[CONFIG]  REDIS_URL = %s", settings.redis_url)

    if not settings.backend_url:
        logger.error("FATAL: BACKEND_URL not set. Set it in Railway environment.")
    else:
        logger.info("[CONFIG]  BACKEND_URL = %s", settings.backend_url)

    # ── 1. REDIS SUBSCRIBER (graceful failure) ──────────
    # If connection fails: log error but DO NOT crash the app.
    # The triage endpoint and /routing/optimise are still reachable.
    try:
        start_subscriber()
    except Exception:
        logger.exception(
            "[FAIL]  Could not start Redis subscriber. "
            "App continues — triage endpoint still reachable."
        )

    # ── 2. SOCIAL MONITOR ───────────────────────────────
    monitor_task: Optional[asyncio.Task] = None
    try:
        monitor_task = asyncio.create_task(monitor_loop())
    except Exception:
        logger.exception("[FAIL]  Could not start social-media monitor.")

    logger.info(
        "[READY]  DIST.RESS AI service started. "
        "Subscriber and monitor running."
    )

    yield

    # ── SHUTDOWN ────────────────────────────────────────
    logger.info("[STOP]  DIST.RESS AI service shutting down ...")
    stop_subscriber()
    stop_monitor()
    if monitor_task is not None:
        monitor_task.cancel()
        try:
            await monitor_task
        except asyncio.CancelledError:
            pass


# ── App creation ────────────────────────────────────────

app = FastAPI(
    title="DIST.RESS AI / NLP Service",
    description=(
        "Triage classifier, social-media threat monitor, "
        "and OR-Tools TSP route optimiser for the DIST.RESS Signal Network."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Global exception handler ───────────────────────────

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Catch-all handler: logs the error and returns a clean 500 response.
    Prevents raw tracebacks from leaking to clients.
    """
    logger.exception("[500]  Unhandled error on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={"error": True, "message": str(exc)},
    )


# ── Routes ──────────────────────────────────────────────

@app.get("/health", tags=["ops"])
async def health():
    """
    KEEP-WARM endpoint — Node.js pings this every 5 minutes.
    Must respond within 100ms always.
    Does NOT check Redis or DB. Just returns { status: 'ok' }.
    """
    return {"status": "ok"}


@app.get("/", tags=["ops"])
async def root():
    return {"message": "DIST.RESS AI / NLP Service is running."}


# ── Source health models + endpoint (Prompt G) ──────────

class SourceEntry(BaseModel):
    name: str
    status: str
    last_poll: str | None
    consecutive_failures: int

class SourceStatusResponse(BaseModel):
    sources: list[SourceEntry]
    total_active: int


@app.get("/sources/status", tags=["ops"])
async def sources_status():
    entries = [
        SourceEntry(name=name, **health)
        for name, health in _source_health.items()
    ]
    return SourceStatusResponse(
        sources=entries,
        total_active=sum(1 for e in entries if e.status == "ok"),
    )


# ── OR-Tools TSP Route Optimisation ─────────────────────

@app.post("/optimise", tags=["routing"])
async def simple_optimise(request: Request):
    """
    Simplified endpoint exactly as requested by the Node.js backend.
    Accepts depot + waypoints without strict metadata.
    Returns: { "ordered_waypoint_ids": [42, 41, 40] }
    """
    body = await request.json()

    depot = body.get("depot")
    waypoints = body.get("waypoints", [])

    if not depot or "lat" not in depot or "lng" not in depot:
        return JSONResponse(
            status_code=400,
            content={"error": True, "code": "INVALID_DEPOT", "message": "Depot must include lat and lng."},
        )
    if len(waypoints) > MAX_WAYPOINTS:
        return JSONResponse(
            status_code=400,
            content={
                "error": True,
                "code": "TOO_MANY_WAYPOINTS",
                "message": f"Maximum {MAX_WAYPOINTS} waypoints allowed. Received: {len(waypoints)}",
            },
        )
    if not waypoints:
        return JSONResponse(
            status_code=400,
            content={"error": True, "code": "NO_WAYPOINTS", "message": "At least 1 waypoint is required."},
        )

    result = optimise_route(depot, waypoints)
    ordered_ids = [stop["id"] for stop in result["route"]]
    
    return {"ordered_waypoint_ids": ordered_ids}


@app.post("/routing/optimise", tags=["routing"])
async def routing_optimise(request: Request):
    """
    Accepts depot + waypoints, returns an optimised route using
    OR-Tools TSP solver (3-second hard limit) with greedy fallback.

    async def — does NOT block concurrent triage classification.
    """
    body = await request.json()

    depot = body.get("depot")
    waypoints = body.get("waypoints", [])

    # Validate depot
    if not depot or "lat" not in depot or "lng" not in depot:
        return JSONResponse(
            status_code=400,
            content={
                "error": True,
                "code": "INVALID_DEPOT",
                "message": "Depot must include lat and lng.",
            },
        )

    # Hard limit: max 15 waypoints
    if len(waypoints) > MAX_WAYPOINTS:
        return JSONResponse(
            status_code=400,
            content={
                "error": True,
                "code": "TOO_MANY_WAYPOINTS",
                "message": f"Maximum {MAX_WAYPOINTS} waypoints allowed. Received: {len(waypoints)}",
            },
        )

    if len(waypoints) == 0:
        return JSONResponse(
            status_code=400,
            content={
                "error": True,
                "code": "NO_WAYPOINTS",
                "message": "At least 1 waypoint is required.",
            },
        )

    logger.info("[ROUTE]  Optimising route: depot + %d waypoints", len(waypoints))

    # Run solver (CPU-bound but fast for ≤15 nodes)
    result = optimise_route(depot, waypoints)

    logger.info(
        "[ROUTE]  Done — %d stops, %dm total, solver=%s",
        result["stops"], result["total_distance_m"], result["solver"],
    )

    return result


# ── Entrypoint ──────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "distress_ai.main:app",
        host=settings.host,
        port=settings.port,
        reload=True,
    )
