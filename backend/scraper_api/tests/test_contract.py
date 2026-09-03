import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from models import Product, SearchResponse
from scrapers.base import parse_price
from services.catalog import rank_search_results, sort_results_for_output
from services.scraper import resolve_stores


class ContractTest(unittest.TestCase):
    def test_parse_price_argentine_format(self):
        self.assertEqual(parse_price("$1.099,00"), 1099)
        self.assertEqual(parse_price("$1.099"), 1099)
        self.assertEqual(parse_price("$1099.50"), 1099.5)

    def test_store_aliases_match_flutter_ids(self):
        self.assertEqual(resolve_stores(["coto", "carrefour", "lagallega"]), ["coto", "carrefour", "la_gallega"])
        self.assertEqual(resolve_stores(["la-gallega"]), ["la_gallega"])
        self.assertEqual(resolve_stores("coto,carrefour,la_gallega"), ["coto", "carrefour", "la_gallega"])

    def test_invalid_store_raises_clear_error(self):
        with self.assertRaisesRegex(ValueError, "Supermercados"):
            resolve_stores(["no_existe"])

    def test_search_response_contract_is_nested_for_flutter(self):
        product = Product(
            store="la_gallega",
            name="Leche Entera Ilolay 1 L",
            price=1099,
            url="https://www.lagallega.com.ar/",
            scraped_at="2026-08-21T00:00:00+00:00",
        )
        match = rank_search_results("leche entera 1l", [product], limit=1)[0]
        response = SearchResponse(
            query="leche entera 1l",
            stores=["la_gallega"],
            count=1,
            results=[match],
        )
        payload = response.model_dump()

        self.assertEqual(payload["results"][0]["product"]["store"], "la_gallega")
        self.assertEqual(payload["results"][0]["product"]["name"], "Leche Entera Ilolay 1 L")
        self.assertEqual(payload["results"][0]["product"]["price"], 1099)
        self.assertGreater(payload["results"][0]["score"], 80)

    def test_ranking_prefers_product_type_over_brand_only_match(self):
        rows = [
            Product(store="coto", name="Crema De Leche LA PAULINA 200cc", price=2640, scraped_at="x"),
            Product(store="coto", name="Dulce De Leche VACALIN 400g", price=4095, scraped_at="x"),
        ]

        ranked = rank_search_results("dulce de leche la paulina", rows, limit=2)

        self.assertEqual(ranked[0].product.name, "Dulce De Leche VACALIN 400g")
        self.assertTrue(all("Dulce" in match.product.name for match in ranked))

    def test_sort_keeps_unpriced_last(self):
        rows = [
            {"store": "coto", "name": "caro", "price": 2500},
            {"store": "coto", "name": "sin precio", "price": None},
            {"store": "coto", "name": "barato", "price": 800},
        ]
        ordered = sort_results_for_output(rows)
        self.assertEqual([row["name"] for row in ordered], ["barato", "caro", "sin precio"])


if __name__ == "__main__":
    unittest.main()
