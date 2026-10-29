import asyncio
from contextlib import asynccontextmanager
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services import scraper


class SearchCacheTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        scraper._search_cache.clear()
        scraper._search_inflight.clear()
        scraper._direct_cache.clear()
        scraper._direct_inflight.clear()

    async def test_concurrent_requests_share_work_and_reuse_cache(self):
        started = asyncio.Event()
        release = asyncio.Event()
        calls = 0

        async def search(*_args):
            nonlocal calls
            calls += 1
            started.set()
            await release.wait()
            return scraper.SearchQueryResult(["one"], {"coto": "ok"})

        with patch.object(scraper, "_scrape_query_uncached", side_effect=search):
            first = asyncio.create_task(scraper.scrape_query("milk", ["coto"], 10, True))
            await started.wait()
            second = asyncio.create_task(scraper.scrape_query("milk", ["coto"], 10, True))
            await asyncio.sleep(0)
            release.set()
            self.assertEqual(await asyncio.gather(first, second), [["one"], ["one"]])
            self.assertEqual(await scraper.scrape_query("milk", ["coto"], 10, True), ["one"])
        self.assertEqual(calls, 1)
        self.assertFalse(scraper._search_inflight)

    async def test_failure_and_empty_result_do_not_stick(self):
        with patch.object(scraper, "_scrape_query_uncached", side_effect=RuntimeError("down")):
            with self.assertRaises(RuntimeError):
                await scraper.scrape_query("milk", ["coto"], 10, True)
        self.assertFalse(scraper._search_inflight)
        with patch.object(scraper, "_scrape_query_uncached", side_effect=[
            scraper.SearchQueryResult([], {"coto": "error"}),
            scraper.SearchQueryResult(["recovered"], {"coto": "ok"}),
        ]) as search:
            self.assertEqual(await scraper.scrape_query("milk", ["coto"], 10, True), [])
            self.assertEqual(await scraper.scrape_query("milk", ["coto"], 10, True), ["recovered"])
        self.assertEqual(search.call_count, 2)

    async def test_cache_is_bounded_and_engine_is_part_of_key(self):
        with patch.object(scraper, "_scrape_query_uncached", return_value=scraper.SearchQueryResult(["one"], {"coto": "ok"})) as search:
            for index in range(scraper._SEARCH_CACHE_MAX_ENTRIES + 5):
                await scraper.scrape_query(f"q{index}", ["coto"], 10, True)
            self.assertLessEqual(len(scraper._search_cache), scraper._SEARCH_CACHE_MAX_ENTRIES)
            await scraper.scrape_query("engine", ["coto"], 10, True, "camoufox")
            await scraper.scrape_query("engine", ["coto"], 10, True, "chromium")
        self.assertEqual(search.call_count, scraper._SEARCH_CACHE_MAX_ENTRIES + 7)

    async def test_browser_failure_preserves_successful_store_and_marks_other_as_error(self):
        async def direct(store, *_args):
            return ["coto product"] if store == "coto" else None

        @asynccontextmanager
        async def broken_browser(**_kwargs):
            raise RuntimeError("browser unavailable")
            yield

        with patch.object(scraper, "_search_one_direct_store", side_effect=direct), patch.object(
            scraper, "open_browser", side_effect=broken_browser
        ):
            result = await scraper.scrape_query_with_status("milk", ["coto", "carrefour"], 10, True)
        self.assertEqual(result.rows, ["coto product"])
        self.assertEqual(result.source_status, {"coto": "ok", "carrefour": "error"})
        self.assertFalse(scraper._search_cache)

    async def test_direct_search_shares_inflight_and_returns_independent_rows(self):
        started = asyncio.Event()
        release = asyncio.Event()
        calls = 0

        async def direct(_query, _limit, *, context):
            nonlocal calls
            calls += 1
            started.set()
            await release.wait()
            return [{"name": "leche", "prices": [100]}]

        with patch.dict(scraper.SCRAPERS, {"coto": SimpleNamespace(search_direct=direct)}):
            first = asyncio.create_task(scraper._search_one_direct_store("coto", "leche", 10, {"branch": "A"}))
            await started.wait()
            second = asyncio.create_task(scraper._search_one_direct_store("coto", "leche", 10, {"branch": "A"}))
            await asyncio.sleep(0)
            release.set()
            a, b = await asyncio.gather(first, second)
            a[0]["prices"].append(200)
            self.assertEqual(b[0]["prices"], [100])
            cached = await scraper._search_one_direct_store("coto", " LEcHe ", 5, {"branch": "A"})
            self.assertEqual(cached[0]["prices"], [100])
        self.assertEqual(calls, 1)
        self.assertFalse(scraper._direct_inflight)

    async def test_direct_cache_separates_branch_and_query_mode(self):
        calls = []

        async def direct(query, limit, *, context):
            calls.append((query, limit, context))
            return [{"name": context["branch"]}]

        with patch.dict(scraper.SCRAPERS, {"coto": SimpleNamespace(search_direct=direct)}):
            for context in (
                {"branch": "A", "equivalence_search": True},
                {"branch": "B", "equivalence_search": True},
                {"branch": "A", "equivalence_search": False},
            ):
                await scraper._search_one_direct_store("coto", "leche", 10, context)
            await scraper._search_one_direct_store(
                "coto", "leche", 5, {"branch": "A", "equivalence_search": True, "latitude": -32.9}
            )
        self.assertEqual(len(calls), 3)

    async def test_direct_failures_retry_and_small_result_does_not_replace_large(self):
        calls = 0

        async def direct(_query, limit, *, context):
            nonlocal calls
            calls += 1
            if calls == 1:
                return None
            return [{"index": i} for i in range(limit)]

        with patch.dict(scraper.SCRAPERS, {"coto": SimpleNamespace(search_direct=direct)}):
            self.assertIsNone(await scraper._search_one_direct_store("coto", "arroz", 10, {}))
            self.assertEqual(len(await scraper._search_one_direct_store("coto", "arroz", 10, {})), 10)
            self.assertEqual(len(await scraper._search_one_direct_store("coto", "arroz", 5, {})), 5)
            self.assertEqual(len(await scraper._search_one_direct_store("coto", "arroz", 10, {})), 10)
        self.assertEqual(calls, 2)
