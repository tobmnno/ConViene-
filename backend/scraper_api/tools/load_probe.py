"""Bounded ASGI load probe with simulated stores; never contacts retailers.

Default duration matches the pre-beta plan. Use short durations for a smoke run.
"""

from __future__ import annotations

import argparse
import asyncio
from contextlib import ExitStack
from datetime import datetime, timezone
import json
from statistics import median
from time import monotonic
import tracemalloc
from unittest.mock import patch

import httpx

from api import app
from models import Product
from scrapers import SCRAPERS
from services.scraper import _direct_cache, _search_cache


def percentile(values: list[float], fraction: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int((len(ordered) - 1) * fraction))]


async def run_phase(client: httpx.AsyncClient, users: int, seconds: float) -> dict:
    deadline = monotonic() + seconds
    latencies: list[float] = []
    errors: list[str] = []

    async def user():
        while monotonic() < deadline:
            started = monotonic()
            try:
                response = await client.get("/search", params={"q": "leche", "limit": 10})
                payload = response.json()
                if response.status_code != 200 or payload.get("partial") or payload.get("count") != len(SCRAPERS):
                    errors.append(f"status={response.status_code}, partial={payload.get('partial')}")
                elif any(row["product"]["ean"] != "7790742358608" for row in payload["results"]):
                    errors.append("fixture identity changed")
            except Exception as exc:
                errors.append(type(exc).__name__)
            latencies.append((monotonic() - started) * 1000)
            await asyncio.sleep(1)

    await asyncio.gather(*(user() for _ in range(users)))
    return {
        "users": users, "seconds": seconds, "requests": len(latencies),
        "errors": len(errors), "error_samples": errors[:3],
        "p50_ms": round(median(latencies), 1) if latencies else 0,
        "p95_ms": round(percentile(latencies, 0.95), 1),
    }


async def probe(users: int, seconds: float, burst_users: int, burst_seconds: float) -> dict:
    _direct_cache.clear()
    _search_cache.clear()
    requests_by_store = {store: 0 for store in SCRAPERS}
    with ExitStack() as stack:
        for store, scraper in SCRAPERS.items():
            async def simulated_search(query, limit=30, context=None, _store=store):
                requests_by_store[_store] += 1
                await asyncio.sleep(0.02)
                return [Product(
                    store=_store, name="Leche de prueba 1 L", ean="7790742358608",
                    price=1000, scraped_at=datetime.now(timezone.utc).isoformat(),
                )]

            stack.enter_context(patch.object(scraper, "search_direct", side_effect=simulated_search))
        tracemalloc.start()
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://load.test") as client:
            steady = await run_phase(client, users, seconds)
            burst = await run_phase(client, burst_users, burst_seconds)
        current, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
    return {
        "steady": steady, "burst": burst,
        "source_calls": requests_by_store,
        "memory_current_mb": round(current / 1_048_576, 2),
        "memory_peak_mb": round(peak / 1_048_576, 2),
        "simulated_sources": True,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--users", type=int, default=10)
    parser.add_argument("--seconds", type=float, default=900)
    parser.add_argument("--burst-users", type=int, default=20)
    parser.add_argument("--burst-seconds", type=float, default=120)
    args = parser.parse_args()
    if min(args.users, args.seconds, args.burst_users, args.burst_seconds) <= 0:
        parser.error("all load settings must be positive")
    result = asyncio.run(probe(args.users, args.seconds, args.burst_users, args.burst_seconds))
    print(json.dumps(result, indent=2))
    failed = any(result[phase]["errors"] or result[phase]["p95_ms"] >= 1000
                 for phase in ("steady", "burst"))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
