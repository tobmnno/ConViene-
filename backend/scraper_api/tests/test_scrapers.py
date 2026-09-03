import os
import unittest

try:
    from camoufox.async_api import AsyncCamoufox
except Exception:
    AsyncCamoufox = None

from main import sort_results_for_output
from models import Product
from services.catalog import rank_search_results
from scrapers import CarrefourScraper, CotoScraper, LaGallegaScraper


@unittest.skipUnless(
    os.getenv("CONVIENE_RUN_SMOKE") == "1" and AsyncCamoufox is not None,
    "set CONVIENE_RUN_SMOKE=1 to run live scraper smoke tests",
)
class ScraperSmokeTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.browser = await AsyncCamoufox(headless=True).__aenter__()
        self.context = await self.browser.new_context(
            locale="es-AR",
            timezone_id="America/Argentina/Cordoba",
        )

    async def asyncTearDown(self):
        await self.context.close()
        await self.browser.__aexit__(None, None, None)

    async def _assert_has_results(self, scraper, query: str = "leche", limit: int = 3):
        page = await self.context.new_page()
        try:
            rows = await scraper.search(page, query, limit)
            self.assertGreater(len(rows), 0, f"{scraper.store} devolvió 0 productos")
            self.assertIsNotNone(rows[0].name)
        finally:
            await page.close()

    async def test_coto_search(self):
        await self._assert_has_results(CotoScraper())

    async def test_carrefour_search(self):
        await self._assert_has_results(CarrefourScraper())

    async def test_lagallega_search(self):
        await self._assert_has_results(LaGallegaScraper())

    def test_sort_results_for_output_keeps_all_and_orders_by_price(self):
        rows = [
            {"store": "coto", "name": "caro", "price": 2500},
            {"store": "coto", "name": "barato", "price": 800},
            {"store": "coto", "name": "medio", "price": 1400},
            {"store": "coto", "name": "sin precio", "price": None},
        ]

        ordered = sort_results_for_output(rows)

        self.assertEqual([r["name"] for r in ordered[:3]], ["barato", "medio", "caro"])
        self.assertEqual(ordered[-1]["name"], "sin precio")
        self.assertEqual(len(ordered), 4)

    def test_rank_search_results_prefers_equivalent_sizes(self):
        rows = [
            Product(store="coto", name="Leche entera 1000 ml", price=1200, scraped_at="2026-08-24T00:00:00Z"),
            Product(store="coto", name="Leche descremada 1L", price=1100, scraped_at="2026-08-24T00:00:00Z"),
            Product(store="coto", name="Agua mineral 2L", price=900, scraped_at="2026-08-24T00:00:00Z"),
        ]

        ranked = rank_search_results("leche entera 1l", rows, limit=3)

        self.assertEqual(ranked[0].product.name, "Leche entera 1000 ml")
        self.assertGreater(ranked[0].score, ranked[1].score)


if __name__ == "__main__":
    unittest.main()
