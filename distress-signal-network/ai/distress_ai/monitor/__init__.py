"""
Social-media / NLP background alert monitor.

Polls a simulated text feed every MONITOR_INTERVAL_SECONDS.  For each
synthetic message, runs NLP to detect threat type and confidence.

Threat types (exact enum strings):
  'earthquake' | 'flood' | 'blast' | 'fire' | 'stampede'

If confidence >= 0.85 AND no cooldown for the threat_type:
  → POST {BACKEND_URL}/api/alert/trigger
    { type, confidence, lat, lng, source: 'nlp' }

If confidence < 0.85:
  → log 'monitoring: {type} at {confidence}', do nothing else.

Cooldown is populated by the 'alert-broadcast' Redis subscriber
(Prompt 2) and checked via is_on_cooldown(threat_type).

NEVER crashes — all work wrapped in try/except.
"""

from __future__ import annotations

import asyncio
import logging
import random
from typing import Dict, List, Set, Tuple

from distress_ai.config import settings
from distress_ai.models import AlertPayload
from distress_ai.routing import post_alert_trigger
from distress_ai.subscriber import is_on_cooldown
from .collectors import RedditCollector, REDDIT_SUBREDDITS

logger = logging.getLogger("distress.monitor")
collector = RedditCollector()

# ── Threat keyword dictionaries ─────────────────────────
# Map each threat type enum to detection keywords.

_THREAT_KEYWORDS: Dict[str, Set[str]] = {
    "earthquake": {
        "earthquake", "tremor", "seismic", "quake",
        "buildings shaking", "richter",
    },
    "flood": {
        "flood", "flooding", "submerged", "water level",
        "dam breach", "inundation", "waterlogged",
    },
    "blast": {
        "blast", "bomb", "explosion", "detonation",
        "explosive", "ied", "shrapnel",
    },
    "fire": {
        "fire", "blaze", "inferno", "wildfire",
        "smoke", "burning", "flames", "arson",
    },
    "stampede": {
        "stampede", "crowd crush", "crowd surge",
        "crowd panic", "trampled", "overcrowding",
    },
}

# ── Simulated threat scenarios (synthetic feed) ─────────

_SIMULATED_POSTS: List[Dict] = [
    {"text": "Beautiful sunset at the park today",
     "lat": 18.52, "lng": 73.86},
    {"text": "Major earthquake tremors felt across the city, buildings shaking violently",
     "lat": 12.95, "lng": 77.58},
    {"text": "Traffic is terrible on MG Road as usual",
     "lat": 12.97, "lng": 77.62},
    {"text": "BREAKING: Reports of severe flooding in low-lying areas, water level rising fast",
     "lat": 13.01, "lng": 77.55},
    {"text": "New cafe opened on Church Street, great coffee!",
     "lat": 12.98, "lng": 77.60},
    {"text": "Massive explosion heard near the industrial area, blast shattered windows",
     "lat": 12.92, "lng": 77.60},
    {"text": "My dog is so cute",
     "lat": 18.50, "lng": 73.85},
    {"text": "URGENT: Fire spreading rapidly through the warehouse district, thick smoke visible",
     "lat": 19.08, "lng": 72.88},
    {"text": "Enjoying the cricket match at Chinnaswamy",
     "lat": 12.98, "lng": 77.60},
    {"text": "Crowd stampede reported at concert venue, people trampled and injured",
     "lat": 28.61, "lng": 77.21},
]


# ── Threat scoring ──────────────────────────────────────

def _score_post(text: str) -> Tuple[str, float, List[str]]:
    """
    Score a post for threat level.
    Returns (threat_type, confidence, matched_keywords).
    """
    lower = text.lower()
    best_type = "unknown"
    best_score = 0.0
    best_kws: List[str] = []

    for threat_type, keywords in _THREAT_KEYWORDS.items():
        matched = [kw for kw in keywords if kw in lower]
        if not matched:
            continue
        # base confidence + boost for multiple keyword hits
        score = 0.70 + min(len(matched), 4) * 0.07
        # urgency signals
        if any(w in lower for w in ("breaking", "urgent", "emergency", "massive")):
            score += 0.05
        caps_ratio = sum(1 for c in text if c.isupper()) / max(len(text), 1)
        if caps_ratio > 0.4:
            score += 0.03
        score = min(score, 1.0)

        if score > best_score:
            best_score = score
            best_type = threat_type
            best_kws = matched

    return best_type, round(best_score, 4), best_kws


# ── Background monitor loop ────────────────────────────

_running = False


async def monitor_loop() -> None:
    """
    Async background task: polls Reddit at the configured
    interval and fires POST /api/alert/trigger when confidence >= 0.85.
    """
    global _running
    _running = True
    logger.info(
        "[INIT]  Reddit monitor started (subs: %s, poll %ds, threshold %.2f)",
        ", ".join(REDDIT_SUBREDDITS),
        settings.monitor_interval_seconds,
        settings.alert_confidence_threshold,
    )

    # --- 24h Backfill / Demo Mode ---
    logger.info("[INIT]  Starting 24h backfill...")
    backfill_posts = collector.fetch_backfill_24h()
    for post in backfill_posts:
        await _process_post(post)
    logger.info("[INIT]  Backfill complete.")

    while _running:
        try:
            # Fetch latest from Reddit
            batch = collector.fetch_latest(limit=5)

            for post in batch:
                await _process_post(post)

        except Exception:
            logger.exception("[FAIL]  Error in Reddit monitor cycle")

        await asyncio.sleep(settings.monitor_interval_seconds)


async def _process_post(post: Dict) -> None:
    """Helper to score and trigger alerts for a single post."""
    threat_type, confidence, kws = _score_post(post["text"])

    if confidence < settings.alert_confidence_threshold:
        if confidence > 0:
            logger.info(
                "monitoring: %s at %.2f", threat_type, confidence,
            )
        return

    # confidence >= 0.85 — check cooldown before calling backend
    if is_on_cooldown(threat_type):
        logger.info(
            "[SKIP]  %s on cooldown, suppressing alert (conf=%.2f)",
            threat_type, confidence,
        )
        return

    logger.warning(
        "[ALERT]  Threat detected!  type=%s  conf=%.2f  kws=%s",
        threat_type, confidence, kws,
    )
    payload = AlertPayload(
        type=threat_type,
        confidence=confidence,
        lat=post["lat"],
        lng=post["lng"],
        source="nlp",
    )
    await post_alert_trigger(payload)


def stop_monitor() -> None:
    """Signal the monitor loop to stop on next cycle."""
    global _running
    _running = False
    logger.info("[STOP]  Social-media monitor stopping.")
