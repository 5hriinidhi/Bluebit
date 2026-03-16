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
from distress_ai.monitor.collectors import fetch_all_platforms, _reddit
from distress_ai.monitor.bart_classifier import classify_post

logger = logging.getLogger("distress.monitor")


# ── Background monitor loop ────────────────────────────

_running = False

# Demo seed posts — always included in every poll cycle
DEMO_POSTS = [
    {
        "id": "demo_001",
        "platform": "reddit",
        "text": "BREAKING: Major earthquake hits Kathmandu Nepal, buildings collapsed, people trapped under debris",
        "url": "https://reddit.com/r/worldnews",
        "created_utc": 0.0,
    },
    {
        "id": "demo_002", 
        "platform": "reddit",
        "text": "Massive flooding reported in Mumbai India, thousands evacuated from low lying areas",
        "url": "https://reddit.com/r/news",
        "created_utc": 0.0,
    },
    {
        "id": "demo_003",
        "platform": "reddit", 
        "text": "Explosion blast reported near Pune railway station, emergency services on site",
        "url": "https://reddit.com/r/india",
        "created_utc": 0.0,
    },
]

_demo_index = 0  # cycles through demo posts one at a time


async def monitor_loop() -> None:
    """
    Async background task: polls cross-platform social feeds at the configured
    interval and fires POST /api/alert/trigger when is_threat is True.
    """
    global _running, _demo_index
    _running = True
    logger.info(
        "[INIT]  Social monitor started (Reddit/Mastodon/Bluesky, poll %ds, threshold %.2f)",
        settings.monitor_interval_seconds,
        settings.alert_confidence_threshold,
    )

    # weather_boost will be imported in Prompt F — leave a comment here for now:
    # from .weather_boost import _cached_boost  # added in Prompt F

    while _running:
        try:
            posts = fetch_all_platforms()

            # Inject one demo post per cycle so demo always has something to show
            demo_post = DEMO_POSTS[_demo_index % len(DEMO_POSTS)]
            _demo_index += 1
            posts.insert(0, demo_post)  # put it first so it classifies first

            if not posts:
                logger.info("[MONITOR] No new posts this cycle")
                await asyncio.sleep(settings.monitor_interval_seconds)
                continue

            for post in posts:
                result = classify_post(post["text"])
                if not result["is_threat"]:
                    continue

                threat_type = result["threat_type"]
                final_confidence = result["confidence"]

                # weather_boost will be added here in Prompt F:
                # final_confidence = min(0.99, final_confidence + _cached_boost)

                print(f"[MONITOR] {post.get('platform', 'unknown')} | {threat_type} | {final_confidence:.3f} | {post.get('url', '')}")

                if is_on_cooldown(threat_type):
                    print(f"[MONITOR] Cooldown active for {threat_type}, skipping")
                    continue

                if final_confidence >= settings.alert_confidence_threshold:
                    logger.warning(
                        "[ALERT]  Threat detected!  type=%s  conf=%.2f  platform=%s",
                        threat_type, final_confidence, post.get("platform", "unknown"),
                    )
                    payload = AlertPayload(
                        type=threat_type,
                        confidence=final_confidence,
                        lat=post.get("lat", 0.0),
                        lng=post.get("lng", 0.0),
                        source="nlp",
                    )
                    await post_alert_trigger(payload)
                else:
                    print(f"[MONITOR] monitoring: {threat_type} at {final_confidence:.3f}")

        except Exception:
            logger.exception("[FAIL]  Error in Social monitor cycle")

        await asyncio.sleep(settings.monitor_interval_seconds)



def stop_monitor() -> None:
    """Signal the monitor loop to stop on next cycle."""
    global _running
    _running = False
    logger.info("[STOP]  Social-media monitor stopping.")
