"""
Centralised configuration loaded from environment variables / .env file.
Uses pydantic-settings for validation. No hardcoded URLs in source.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── Connection URLs (MUST be set via environment / .env) ──
    redis_url: str = ""
    backend_url: str = ""

    # ── Triage ────────────────────────────────────────────────
    triage_confidence_threshold: float = 0.70

    # ── Social-media monitor ─────────────────────────────────
    alert_confidence_threshold: float = 0.85
    monitor_interval_seconds: int = 30       # configurable via env

    # ── External APIs ────────────────────────────────────────
    owm_key: str = ""
    ai_service_url: str = ""

    # ── Server ───────────────────────────────────────────────
    host: str = "0.0.0.0"
    port: int = 8001


settings = Settings()
