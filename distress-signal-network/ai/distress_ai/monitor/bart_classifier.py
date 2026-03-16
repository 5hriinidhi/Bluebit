import logging

logger = logging.getLogger("distress.monitor.bart")

CANDIDATE_LABELS = [
    "earthquake", "flood", "blast", "fire", "stampede",
    "not a disaster or emergency", "casual conversation", "food"
]

FALLBACK_KEYWORDS = {
    "earthquake": ["earthquake", "quake", "tremor", "seismic"],
    "flood":      ["flood", "flooding", "inundation", "submerged"],
    "blast":      ["blast", "explosion", "bomb", "detonation"],
    "fire":       ["fire", "wildfire", "inferno", "burning"],
    "stampede":   ["stampede", "crowd crush", "crowd disaster"],
}

_pipeline = None   # singleton — loaded once on first call

def _get_pipeline():
    global _pipeline
    if _pipeline is None:
        try:
            from transformers import pipeline
            _pipeline = pipeline(
                "zero-shot-classification",
                model="facebook/bart-large-mnli",
                device=-1,   # CPU — Render free tier has no GPU
            )
            logger.info("[BART] Model loaded successfully")
        except Exception as e:
            logger.error(f"[BART] Model load failed, using keyword fallback: {e}")
            _pipeline = "fallback"
    return _pipeline

def classify_post(text: str) -> dict:
    """
    Returns: {
        "threat_type":  str,   # one of the 5 enum values, or "none"
        "confidence":   float, # 0.0 to 1.0
        "is_threat":    bool,  # True if label != "not a disaster" AND score >= 0.55
    }
    """
    pipe = _get_pipeline()

    if pipe == "fallback":
        text_lower = text.lower()
        for threat_type, kws in FALLBACK_KEYWORDS.items():
            if any(kw in text_lower for kw in kws):
                return {"threat_type": threat_type, "confidence": 0.60, "is_threat": True}
        return {"threat_type": "none", "confidence": 0.0, "is_threat": False}

    try:
        # Without multi_label=True, softmax forces choices to compete.
        # This makes "not a disaster" or "casual conversation" win heavily
        # over threats for benign inputs.
        result = pipe(text[:512], candidate_labels=CANDIDATE_LABELS)
        top_label = result["labels"][0]
        top_score = result["scores"][0]
        
        # Explicit non-threat labels
        non_threats = {"not a disaster or emergency", "casual conversation", "food"}
        
        is_threat = (top_label not in non_threats and top_score >= 0.55)
        return {
            "threat_type": top_label if is_threat else "none",
            "confidence":  round(top_score, 4),
            "is_threat":   is_threat,
        }
    except Exception as e:
        logger.error(f"[BART] classify error: {e}")
        return {"threat_type": "none", "confidence": 0.0, "is_threat": False}

def classify_batch(texts: list[str]) -> list[dict]:
    return [classify_post(t) for t in texts]
