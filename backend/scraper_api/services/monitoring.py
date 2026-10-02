from __future__ import annotations

from collections import defaultdict, deque
from datetime import datetime, timezone
import json
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
from threading import Lock
from time import perf_counter
from typing import Any


DATA_DIR = Path(__file__).resolve().parents[1] / "data"
RUNTIME_DIR = DATA_DIR / "runtime"
LOG_FILE = RUNTIME_DIR / "scraper-events.jsonl"
_lock = Lock()
_events: deque[dict[str, Any]] = deque(maxlen=150)
_stats: dict[str, dict[str, Any]] = defaultdict(
    lambda: {"successes": 0, "failures": 0, "consecutive_failures": 0, "last_success_at": None, "last_error": None, "last_duration_ms": None}
)


def _logger() -> logging.Logger:
    logger = logging.getLogger("conviene.scrapers")
    if logger.handlers:
        return logger
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    handler = RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=3, encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.propagate = False
    return logger


def record_check(source: str, *, success: bool, duration_ms: float, detail: str = "", count: int | None = None) -> None:
    event = {
        "at": datetime.now(timezone.utc).isoformat(),
        "source": source,
        "success": success,
        "duration_ms": round(duration_ms, 1),
        "detail": detail[:500],
        "count": count,
    }
    with _lock:
        state = _stats[source]
        state["last_duration_ms"] = event["duration_ms"]
        if success:
            state["successes"] += 1
            state["consecutive_failures"] = 0
            state["last_success_at"] = event["at"]
        else:
            state["failures"] += 1
            state["consecutive_failures"] += 1
            state["last_error"] = event["detail"] or "Fuente sin respuesta"
        _events.append(event)
    _logger().info(json.dumps(event, ensure_ascii=False))


def timed_check(source: str):
    started = perf_counter()

    def finish(*, success: bool, detail: str = "", count: int | None = None) -> None:
        record_check(source, success=success, duration_ms=(perf_counter() - started) * 1000, detail=detail, count=count)

    return finish


def status_snapshot() -> dict[str, Any]:
    with _lock:
        sources = {name: dict(value) for name, value in _stats.items()}
        alerts = [
            {"source": name, "message": f"{value['consecutive_failures']} fallas consecutivas", "severity": "warning"}
            for name, value in sources.items()
            if value["consecutive_failures"] >= 2
        ]
        return {
            "status": "degraded" if alerts else "ok",
            "sources": sources,
            "alerts": alerts,
            "recent_events": list(_events)[-20:],
            "log_file": str(LOG_FILE),
        }
