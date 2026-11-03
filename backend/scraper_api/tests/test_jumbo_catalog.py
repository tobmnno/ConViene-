import unittest
from unittest.mock import patch

from scrapers.stores import _jumbo_api_search
from services.discounts import scrape_discounts
from services.scraper import resolve_stores


class JumboCatalogTest(unittest.TestCase):
    def test_public_catalog_maps_verified_fields_without_inventing_promotion(self):
        payload = [{
            "productName": "Leche Uat Proteina 1 Lt La Serenisima",
            "brand": "La Serenisima",
            "link": "https://www.jumbo.com.ar/leche-uat-proteina-1-lts-la-serenisima/p",
            "items": [{
                "ean": "7790742358608",
                "images": [{"imageUrl": "https://jumboargentina.vteximg.com.br/arquivos/ids/907867/test.jpg"}],
                "sellers": [{"commertialOffer": {
                    "Price": 3350, "ListPrice": 335000, "IsAvailable": True,
                }}],
            }],
        }]
        response = type("Response", (), {"status_code": 206, "json": lambda self: payload})()
        with patch("scrapers.stores.requests.get", return_value=response) as get:
            rows = _jumbo_api_search("7790742358608", 5)
        self.assertEqual(get.call_args.kwargs["params"]["fq"], "alternateIds_Ean:7790742358608")
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].ean, "7790742358608")
        self.assertEqual(rows[0].price, 3350)
        self.assertIsNone(rows[0].regular_price)
        self.assertEqual(rows[0].quantity_offers, [])
        self.assertEqual(rows[0].store, "jumbo")
        self.assertEqual(rows[0].pricing_scope, "online_catalog_unknown_location")

    def test_source_error_is_not_confirmed_absence(self):
        response = type("Response", (), {"status_code": 403})()
        with patch("scrapers.stores.requests.get", return_value=response):
            self.assertIsNone(_jumbo_api_search("leche", 5))

    def test_store_is_resolvable(self):
        self.assertEqual(resolve_stores(["jumbo"]), ["jumbo"])

    def test_unverified_discount_source_does_not_borrow_another_store(self):
        response = scrape_discounts(["jumbo"])
        self.assertEqual(response.results, [])
        self.assertTrue(any("jumbo" in warning for warning in response.warnings))


if __name__ == "__main__":
    unittest.main()
