"""Collect candidate identity pairs from the stores' public catalog responses.

Run manually; review every proposed label before replacing the frozen fixture.
This tool never runs as part of the test suite.
"""

from __future__ import annotations

from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
from pathlib import Path

from models import Product
from scrapers.stores import _carrefour_api_search, _coto_api_search, _lagallega_api_search
from services.catalog import _size_is_compatible, normalize_text, valid_gtin


QUERIES = (
    "leche la serenisima", "oreo", "yerba taragui", "coca cola",
    "dulce de leche la paulina", "preservativo tulipan",
)
SOURCES = {
    "coto": _coto_api_search,
    "carrefour": _carrefour_api_search,
    "la_gallega": _lagallega_api_search,
}
OUTPUT = Path(__file__).resolve().parents[3] / ".pytest_cache" / "product_identity_candidates.json"


def _row(product: Product) -> dict:
    return {
        "store": product.store,
        "name": product.name,
        "brand": product.brand or "",
        "ean": product.ean or "",
        "url": product.url or "",
    }


def main() -> None:
    jobs = [(query, store, source) for query in QUERIES for store, source in SOURCES.items()]
    with ThreadPoolExecutor(max_workers=3) as executor:
        results = list(executor.map(lambda job: (job[0], job[1], job[2](job[0], 8)), jobs))
    failed = [(query, store) for query, store, rows in results if rows is None]
    if failed:
        raise RuntimeError(f"Incomplete catalog capture: {failed}")
    grouped: dict[str, list[Product]] = {query: [] for query in QUERIES}
    for query, _, rows in results:
        grouped[query].extend(rows or [])

    positives = []
    negatives = []
    seen = set()
    for query, products in grouped.items():
        for index, left in enumerate(products):
            for right in products[index + 1:]:
                if left.store == right.store or not left.url or not right.url:
                    continue
                left_ean, right_ean = valid_gtin(left.ean), valid_gtin(right.ean)
                if not left_ean or not right_ean:
                    continue
                pair_key = tuple(sorted((left.url, right.url)))
                if pair_key in seen:
                    continue
                seen.add(pair_key)
                item = {"query": query, "selected": _row(left), "candidate": _row(right)}
                left_size, right_size = normalize_text(left.name), normalize_text(right.name)
                if left_ean == right_ean and _size_is_compatible(left_size, right_size):
                    positives.append(item)
                elif left_ean != right_ean:
                    negatives.append(item)

    payload = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "source": "public_catalog_response",
        "queries": list(QUERIES),
        "status": {f"{query}:{store}": len(rows or []) for query, store, rows in results},
        "positive_candidates": positives,
        "negative_candidates": negatives,
    }
    OUTPUT.parent.mkdir(exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Captured {len(positives)} positive and {len(negatives)} negative candidates")
    print("Positive store pairs:", dict(Counter(tuple(sorted((x["selected"]["store"], x["candidate"]["store"]))) for x in positives)))
    print("Candidate file:", OUTPUT)


if __name__ == "__main__":
    main()
