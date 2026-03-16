import requests
import logging
import time
import re
import datetime
from typing import List, Dict, Set

logger = logging.getLogger("distress.collectors")

# Use the username provided by the user
REDDIT_HEADERS = {
    "User-Agent": "python:distress-intel:1.0 (by u/Late-Pitch-5514)",
}

REDDIT_SUBREDDITS = ["DisasterUpdate", "worldnews", "news", "collapse", "flooding", "earthquake", "india"]
REDDIT_KEYWORDS = [
    "earthquake", "flood", "blast", "explosion", "fire",
    "collapse", "stampede", "cyclone", "tsunami", "landslide",
]

class RedditCollector:
    """Enhanced collector with multi-subreddit support, keyword filtering, and geocoding."""
    
    def __init__(self):
        self.headers = REDDIT_HEADERS
        self.seen_ids: Set[str] = set()
        # Expanded mapping for approximate geocoding
        self.location_map = {
            # USA
            "indiana": (40.2672, -86.1349), "illinois": (40.6331, -89.3985), "kankakee": (41.1200, -87.8600),
            "california": (36.7783, -119.4179), "texas": (31.9686, -99.9018), "florida": (27.6648, -81.5158),
            "new york": (40.7128, -74.0060), "ohio": (40.4173, -82.9071), "oklahoma": (35.4676, -97.5164),
            # Asia
            "japan": (36.2048, 138.2529), "china": (35.8617, 104.1954), "indonesia": (-0.7893, 113.9213),
            "philippines": (12.8797, 121.7740), "turkey": (38.9637, 35.2433), "syria": (34.8021, 38.9968),
            "india": (20.5937, 78.9629), "pune": (18.5204, 73.8567), "mumbai": (19.0760, 72.8777),
            "delhi": (28.6139, 77.2090), "bangalore": (12.9716, 77.5946), "kerala": (10.8505, 76.2711),
            # Europe
            "ukraine": (48.3794, 31.1656), "italy": (41.8719, 12.5674), "greece": (39.0742, 21.8243),
            "spain": (40.4637, -3.7492), "iceland": (64.9631, -19.0208),
            # South/Central America
            "brazil": (-14.2350, -51.9253), "mexico": (23.6345, -102.5528), "chile": (-35.6751, -71.5430),
            "peru": (-9.1900, -75.0152), "ecuador": (-1.8312, -78.1834),
            # Africa
            "morocco": (31.7917, -7.0926), "libya": (26.3351, 17.2283), "south africa": (-30.5595, 22.9375),
            "nigeria": (9.0820, 8.6753), "kenya": (-0.0236, 37.9062),
            # Oceania
            "australia": (-25.2744, 133.7751), "new zealand": (-40.9006, 174.8860), "fiji": (-17.7134, 178.0650),
        }

    def _geocode(self, title: str) -> Dict[str, float]:
        """Extract approximate coordinates from the title."""
        title_lower = title.lower()
        for loc, coords in self.location_map.items():
            if loc in title_lower:
                return {"lat": coords[0], "lng": coords[1]}
        return {"lat": 20.0, "lng": 77.0}

    def collect(self, limit: int = 25) -> List[Dict]:
        """Fetch news from multiple subreddits and filter by keywords."""
        posts = []
        for sub in REDDIT_SUBREDDITS:
            try:
                url = f"https://www.reddit.com/r/{sub}/new.json"
                r = requests.get(url, params={"limit": limit}, headers=self.headers, timeout=8)
                if r.status_code != 200:
                    logger.warning(f"[REDDIT] {sub} returned {r.status_code}")
                    continue
                
                for child in r.json()["data"]["children"]:
                    d = child["data"]
                    if d["id"] in self.seen_ids:
                        continue
                        
                    title = d["title"]
                    selftext = d.get("selftext", "")
                    full_text = (title + " " + selftext).lower()
                    
                    if not any(kw in full_text for kw in REDDIT_KEYWORDS) and sub != "DisasterUpdate":
                        # r/DisasterUpdate is already filtered by topic, but others need keywords
                        continue
                        
                    self.seen_ids.add(d["id"])
                    if len(self.seen_ids) > 5000:
                        # Prevent memory growth
                        # In Python, set doesn't have pop(0), so we just clear and restart or remove random
                        # Clearing is safest for long runs if we reach 5000
                        self.seen_ids.clear()
                        self.seen_ids.add(d["id"])
                    
                    coords = self._geocode(title)
                    posts.append({
                        "id": d["id"],
                        "platform": "reddit",
                        "text": title + " " + selftext[:300],
                        "lat": coords["lat"],
                        "lng": coords["lng"],
                        "url": "https://reddit.com" + d["permalink"],
                        "created_utc": d["created_utc"],
                    })
            except Exception as e:
                logger.error(f"[REDDIT] {sub} error: {e}")
                _update_source_health("reddit", ok=False)
        
        _update_source_health("reddit", ok=True)
        logger.info(f"[REDDIT] Collected {len(posts)} new posts")
        return posts

    def fetch_latest(self, limit: int = 5) -> List[Dict]:
        """Alias for collect() to maintain compatibility with updated monitor loop."""
        return self.collect(limit=limit)

    def fetch_backfill_24h(self) -> List[Dict]:
        """Fetch posts from the last 24h across all subreddits."""
        return self.collect(limit=100)


SOCIAL_KEYWORDS = [
    "earthquake", "flood", "blast", "fire", "collapse", "stampede", "cyclone", "tsunami",
]

# ── Shared health tracker (used by all collectors) ───────────────────────────
_source_health: Dict = {
    "reddit":         {"status": "ok", "last_poll": None, "consecutive_failures": 0},
    "mastodon":       {"status": "ok", "last_poll": None, "consecutive_failures": 0},
    "bluesky":        {"status": "ok", "last_poll": None, "consecutive_failures": 0},
    "news_feed":      {"status": "ok", "last_poll": None, "consecutive_failures": 0},
    "openweathermap": {"status": "ok", "last_poll": None, "consecutive_failures": 0},
}

def _update_source_health(name: str, ok: bool) -> None:
    h = _source_health[name]
    if ok:
        h["status"] = "ok"
        h["last_poll"] = datetime.datetime.utcnow().isoformat() + "Z"
        h["consecutive_failures"] = 0
    else:
        h["consecutive_failures"] += 1
        if h["consecutive_failures"] >= 3:
            h["status"] = "degraded"


# ── Mastodon ─────────────────────────────────────────────────────────────────
class MastodonCollector:
    BASE = "https://mastodon.social/api/v2/search"

    def __init__(self):
        self.seen_ids: Set[str] = set()

    def collect(self) -> List[Dict]:
        import re as _re
        posts = []
        try:
            for kw in SOCIAL_KEYWORDS:
                resp = requests.get(
                    self.BASE,
                    params={"q": kw, "type": "statuses", "limit": 10},
                    headers={"User-Agent": "distress-intel/1.0"},
                    timeout=8,
                )
                for s in resp.json().get("statuses", []):
                    if s["id"] in self.seen_ids:
                        continue
                    self.seen_ids.add(s["id"])
                    clean = _re.sub(r"<[^>]+>", " ", s.get("content", "")).strip()
                    posts.append({
                        "id": s["id"],
                        "platform": "mastodon",
                        "text": clean,
                        "url": s.get("url", ""),
                        "created_utc": 0.0,
                    })
            _update_source_health("mastodon", ok=True)
        except Exception as e:
            logger.error(f"[MASTODON] error: {e}")
            _update_source_health("mastodon", ok=False)
        logger.info(f"[MASTODON] Collected {len(posts)} new posts")
        return posts


# ── Bluesky ──────────────────────────────────────────────────────────────────
class BlueskyCollector:
    BASE = "https://public.api.bsky.app/xrpc/app.bsky.feed.searchPosts"

    def __init__(self):
        self.seen_ids: Set[str] = set()

    def collect(self) -> List[Dict]:
        posts = []
        try:
            for kw in SOCIAL_KEYWORDS:
                resp = requests.get(
                    self.BASE,
                    params={"q": kw, "limit": 10},
                    timeout=8,
                )
                if resp.status_code != 200:
                    logger.warning(f"[BLUESKY] {kw} returned {resp.status_code}")
                    continue
                for post in resp.json().get("posts", []):
                    cid = post.get("cid", "")
                    if cid in self.seen_ids:
                        continue
                    self.seen_ids.add(cid)
                    posts.append({
                        "id": cid,
                        "platform": "bluesky",
                        "text": post.get("record", {}).get("text", ""),
                        "url": "",
                        "created_utc": 0.0,
                    })
            _update_source_health("bluesky", ok=True)
        except Exception as e:
            logger.error(f"[BLUESKY] error: {e}")
            _update_source_health("bluesky", ok=False)
        logger.info(f"[BLUESKY] Collected {len(posts)} new posts")
        return posts


# ── Combined entry point called by social.py ─────────────────────────────────
_reddit   = RedditCollector()
_mastodon = MastodonCollector()
_bluesky  = BlueskyCollector()

def fetch_all_platforms() -> List[Dict]:
    """Collect posts from Reddit, Mastodon, and Bluesky."""
    posts: List[Dict] = []
    posts += _reddit.collect()
    posts += _mastodon.collect()
    posts += _bluesky.collect()
    return posts
