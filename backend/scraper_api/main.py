import argparse
import asyncio
import json
from pathlib import Path

from scrapers import SCRAPERS
from services.catalog import sort_results_for_output
from services.scraper import STORE_ALIASES, resolve_stores, scrape_query


async def run(
    query: str,
    stores: list[str],
    limit: int,
    headless: bool,
    engine: str = "camoufox",
):
    selected_stores = resolve_stores(stores)
    all_rows = await scrape_query(query, selected_stores, limit, headless, engine)
    all_rows = sort_results_for_output(all_rows)
    all_rows = [row if isinstance(row, dict) else row.model_dump() for row in all_rows]
    Path("output.json").write_text(
        json.dumps(all_rows, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return all_rows


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("query")
    ap.add_argument(
        "--stores",
        nargs="+",
        choices=sorted(STORE_ALIASES),
        default=list(SCRAPERS),
    )
    ap.add_argument("--limit", type=int, default=30)
    ap.add_argument("--headed", action="store_true")
    ap.add_argument(
        "--engine",
        choices=["camoufox", "chromium"],
        default="camoufox",
        help="Motor de navegador. Camoufox es el predeterminado.",
    )
    a = ap.parse_args()
    asyncio.run(run(a.query, a.stores, a.limit, not a.headed, a.engine))
