from __future__ import annotations

import json
from datetime import datetime, timezone
from html import unescape
from pathlib import Path
import re
from time import perf_counter
from typing import Any

import requests

from scrapers.stores import REQUEST_HEADERS
from services.monitoring import record_check


DATA_DIR = Path(__file__).resolve().parents[1] / "data"
RUNTIME_DIR = DATA_DIR / "runtime"
LAGALLEGA_CATALOG_FILE = RUNTIME_DIR / "la-gallega-catalog.json"
LAGALLEGA_BLINK_URL = "https://www.blinkapp.com.ar/comercios/la-gallega--merchant_69e2584eab6e5feb86137a1a"


def load_lagallega_catalog() -> dict[str, Any]:
    try:
        with LAGALLEGA_CATALOG_FILE.open("r", encoding="utf-8") as source:
            payload = json.load(source)
    except (OSError, json.JSONDecodeError):
        return {}
    return payload if isinstance(payload, dict) else {}


def catalog_is_stale(payload: dict[str, Any], *, max_age_seconds: int = 21_600) -> bool:
    checked_at = payload.get("checked_at")
    if not isinstance(checked_at, str):
        return True
    try:
        checked = datetime.fromisoformat(checked_at.replace("Z", "+00:00"))
    except ValueError:
        return True
    return (datetime.now(timezone.utc) - checked).total_seconds() >= max_age_seconds


def refresh_lagallega_catalog(*, force: bool = False) -> dict[str, Any]:
    existing = load_lagallega_catalog()
    if not force and existing and not catalog_is_stale(existing):
        return existing

    started = perf_counter()
    try:
        response = requests.get(LAGALLEGA_BLINK_URL, headers=REQUEST_HEADERS, timeout=25)
        response.raise_for_status()
        match = re.search(
            r'<script[^>]*id=["\']blink-merchant-bootstrap["\'][^>]*>(.*?)</script>',
            response.text,
            flags=re.I | re.S,
        )
        if not match:
            raise ValueError("El feed estructurado de La Gallega no esta disponible")
        payload = json.loads(unescape(match.group(1)))
        business = payload.get("business") if isinstance(payload, dict) else None
        benefits = business.get("benefits") if isinstance(business, dict) else None
        if not isinstance(benefits, list):
            raise ValueError("El feed no incluyo beneficios")
        catalog = {
            "checked_at": datetime.now(timezone.utc).isoformat(),
            "source_url": LAGALLEGA_BLINK_URL,
            "benefits": benefits,
            "locations": business.get("location", []) if isinstance(business, dict) else [],
            "source_benefit_count": len(benefits),
        }
        RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
        temporary = LAGALLEGA_CATALOG_FILE.with_suffix(".tmp")
        temporary.write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8")
        temporary.replace(LAGALLEGA_CATALOG_FILE)
        record_check("promotions.la_gallega", success=True, duration_ms=(perf_counter() - started) * 1000, count=len(benefits))
        return catalog
    except (requests.RequestException, ValueError, json.JSONDecodeError, OSError) as exc:
        record_check("promotions.la_gallega", success=False, duration_ms=(perf_counter() - started) * 1000, detail=f"{type(exc).__name__}: {exc}")
        return existing
