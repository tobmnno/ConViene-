"""Opt-in live benchmark for progressive catalog lookup; never run in pytest."""

from __future__ import annotations

import asyncio
from collections import Counter
from datetime import datetime, timezone
import json
from math import ceil
from pathlib import Path
from statistics import median
from time import perf_counter

from services import scraper
from services.monitoring import status_snapshot


QUERIES = (
    "leche la serenisima", "oreo", "yerba taragui", "coca cola",
    "dulce de leche la paulina", "preservativo tulipan",
)
STORES = ("coto", "carrefour", "la_gallega")
ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / ".pytest_cache" / "search-benchmark.json"


def percentile(values: list[float], percentage: float) -> float:
    ordered = sorted(values)
    return round(ordered[min(len(ordered) - 1, ceil(len(ordered) * percentage) - 1)], 3)


async def run_query(query: str) -> dict:
    before = status_snapshot()["sources"]
    started = perf_counter()
    pending = {
        asyncio.create_task(scraper._search_one_direct_store(store, query, 30, {})): store
        for store in STORES
    }
    first = None
    status = {}
    for task in asyncio.as_completed(pending):
        rows = await task
        if first is None and rows:
            first = perf_counter() - started
    for task, store in pending.items():
        rows = task.result()
        status[store] = "error" if rows is None else f"{len(rows)} results"
    after = status_snapshot()["sources"]
    requests = {
        store: sum(after.get(f"products.{store}", {}).get(key, 0) - before.get(f"products.{store}", {}).get(key, 0)
                   for key in ("successes", "failures"))
        for store in STORES
    }
    return {
        "query": query, "first_useful_seconds": round(first, 3) if first is not None else None,
        "complete_seconds": round(perf_counter() - started, 3),
        "upstream_requests": requests, "status": status,
    }


def summarize(rows: list[dict]) -> dict:
    first = [row["first_useful_seconds"] for row in rows if row["first_useful_seconds"] is not None]
    complete = [row["complete_seconds"] for row in rows]
    requests = Counter()
    errors = Counter()
    for row in rows:
        requests.update(row["upstream_requests"])
        errors.update(store for store, status in row["status"].items() if status == "error")
    return {
        "first_p50": median(first) if first else None,
        "first_p95": percentile(first, .95) if first else None,
        "complete_p50": median(complete), "complete_p95": percentile(complete, .95),
        "requests": dict(requests), "errors": dict(errors),
    }


async def main() -> None:
    scraper._direct_cache.clear()
    cold = [await run_query(query) for query in QUERIES]
    warm = [await run_query(query) for query in QUERIES]
    report = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "queries": list(QUERIES), "stores": list(STORES), "limit": 30,
        "cold": {"summary": summarize(cold), "samples": cold},
        "warm": {"summary": summarize(warm), "samples": warm},
    }
    OUTPUT.parent.mkdir(exist_ok=True)
    OUTPUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({mode: report[mode]["summary"] for mode in ("cold", "warm")}, indent=2))
    print("Samples:", OUTPUT)


if __name__ == "__main__":
    asyncio.run(main())
