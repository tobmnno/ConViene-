import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from models import DiscountPromotion, DiscountsResponse, Product, SearchResponse
from scrapers.base import parse_price
from services.catalog import (
    extract_measurement,
    products_are_comparable,
    rank_search_results,
    search_query_for_product_name,
    sort_results_for_output,
)
from services.discounts import _coto_from_api
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

    def test_discounts_response_contract_matches_flutter(self):
        promotion = DiscountPromotion(
            id="la_gallega_banco_santa_fe",
            store="la_gallega",
            title="Banco Santa Fe",
            benefit="30% OFF",
            payment_type="bank",
            entity="Banco Santa Fe",
            percentage=30,
            refund_cap=25000,
            weekdays=[1, 2, 3, 4, 5, 6, 7],
            start_date="2026-09-01",
            end_date="2026-12-31",
            conditions="30% de reintegro con tarjeta fisica Banco Santa Fe.",
            categories=["todos"],
            source_url="https://www.lagallega.com.ar/Beneficios.asp",
            compatible_entities=["Banco Santa Fe", "Visa", "Mastercard"],
            compatible_payment_types=["bank", "card"],
            scraped_at="2026-09-04T00:00:00+00:00",
        )
        response = DiscountsResponse(
            date="2026-09-04",
            stores=["la_gallega"],
            count=1,
            results=[promotion],
            warnings=[],
        )
        payload = response.model_dump()

        self.assertEqual(payload["results"][0]["store"], "la_gallega")
        self.assertEqual(payload["results"][0]["percentage"], 30)
        self.assertEqual(payload["results"][0]["refund_cap"], 25000)
        self.assertIn("Banco Santa Fe", payload["results"][0]["compatible_entities"])

    def test_brand_specific_search_rejects_other_brands_and_product_types(self):
        rows = [
            Product(store="coto", name="Crema De Leche LA PAULINA 200cc", price=2640, scraped_at="x"),
            Product(store="coto", name="Dulce De Leche VACALIN 400g", price=4095, scraped_at="x"),
            Product(store="coto", name="Dulce De Leche LA PAULINA 400g", price=4200, scraped_at="x"),
        ]

        ranked = rank_search_results("dulce de leche la paulina 400g", rows, limit=3)

        self.assertEqual([match.product.name for match in ranked], ["Dulce De Leche LA PAULINA 400g"])

    def test_product_search_query_removes_percent_noise_but_keeps_size(self):
        query = search_query_for_product_name("Leche La Serenisima Liviana 1% 1L")

        self.assertEqual(query, "Leche La Serenisima Liviana 1L")

    def test_pack_measurement_uses_total_quantity(self):
        self.assertEqual(extract_measurement("Galletitas Oreo pack 3 x 118 g"), (354.0, "g"))
        self.assertEqual(extract_measurement("Jugo 200 ml x 6 un"), (1200.0, "ml"))
        self.assertEqual(extract_measurement("Galletitas Oreo 118 grs"), (118.0, "g"))

    def test_ranking_rejects_wrong_size_pack_percentage_and_variant(self):
        rows = [
            Product(store="coto", name="Leche La Serenisima Liviana 1% 1 L", price=2000, scraped_at="x"),
            Product(store="coto", name="Leche La Serenisima Mas Liviana 2% 1 L", price=1900, scraped_at="x"),
            Product(store="coto", name="Leche La Serenisima Liviana 1% 1.5 L", price=1800, scraped_at="x"),
            Product(store="coto", name="Leche Ilolay Liviana 1% 1 L", price=1700, scraped_at="x"),
        ]

        ranked = rank_search_results("leche la serenisima liviana 1% 1l", rows)

        self.assertEqual([match.product.name for match in ranked], ["Leche La Serenisima Liviana 1% 1 L"])
        self.assertEqual(ranked[0].match_type, "exact")

    def test_ranking_understands_synonyms_and_rejects_opposites(self):
        rows = [
            Product(store="coto", name="Mayonesa Hellmanns Liviana 475 g", price=2000, scraped_at="x"),
            Product(store="coto", name="Mayonesa Hellmanns Clasica 475 g", price=1900, scraped_at="x"),
            Product(store="coto", name="Mayonesa Natura Light 475 g", price=1800, scraped_at="x"),
            Product(store="coto", name="Yerba Taragui Sin Palo 1 kg", price=5000, scraped_at="x"),
            Product(store="coto", name="Yerba Taragui Con Palo 1 kg", price=4500, scraped_at="x"),
        ]

        mayonnaise = rank_search_results("mayonesa hellmanns light 475g", rows)
        yerba = rank_search_results("yerba taragui sin palo 1kg", rows)

        self.assertEqual([match.product.name for match in mayonnaise], ["Mayonesa Hellmanns Liviana 475 g"])
        self.assertEqual([match.product.name for match in yerba], ["Yerba Taragui Sin Palo 1 kg"])

    def test_unknown_requested_variant_is_labeled_similar(self):
        rows = [
            Product(store="coto", name="Galletitas Oreo 118 g", price=2000, scraped_at="x"),
            Product(store="coto", name="Galletitas Oreo Frutilla 118 g", price=2200, scraped_at="x"),
        ]

        ranked = rank_search_results("galletitas oreo frutilla 118g", rows)

        self.assertEqual(ranked[0].match_type, "exact")
        self.assertEqual(ranked[1].match_type, "similar")

    def test_unrequested_distinguishing_variant_is_labeled_similar(self):
        rows = [
            Product(store="coto", name="Galletitas Oreo Chocolate Rellenas 118 g", price=2000, scraped_at="x"),
            Product(store="coto", name="Galletitas Oreo Chocolate Bañadas 118 g", price=2200, scraped_at="x"),
        ]

        ranked = rank_search_results("galletitas oreo chocolate 118g", rows)

        self.assertTrue(all(match.match_type == "similar" for match in ranked))
        exact = rank_search_results("galletitas oreo chocolate rellenas 118g", rows)
        self.assertEqual([match.product.name for match in exact], ["Galletitas Oreo Chocolate Rellenas 118 g"])
        self.assertEqual(exact[0].match_type, "exact")

    def test_comparison_rejects_different_sizes_packs_and_flavors(self):
        self.assertTrue(
            products_are_comparable(
                "Galletitas Oreo chocolate 3 x 118 g",
                "Galletitas Oreo chocolate pack 3 x 117 g",
            )
        )
        self.assertFalse(
            products_are_comparable(
                "Galletitas Oreo chocolate 3 x 118 g",
                "Galletitas Oreo chocolate 354 g",
            )
        )
        self.assertFalse(
            products_are_comparable("Crema La Paulina 200 cc", "Crema La Paulina 350 cc")
        )
        self.assertFalse(
            products_are_comparable("Yogur vainilla 1 L", "Yogur frutilla 1 L")
        )
        self.assertFalse(
            products_are_comparable(
                "Galletitas Oreo chocolate 3 x 118 g",
                "Galletitas Criollitas lacteadas 3 x 118 g",
            )
        )

    def test_coto_official_payload_maps_day_cap_and_entity(self):
        row = _coto_from_api(
            {
                "id": "330",
                "textoDescuento": "30% DE DESCUENTO",
                "descripcion": "En un pago con tarjetas credito y debito Visa de Banco Comafi",
                "observacion": "Tope de reintegro $ 15.000 por transaccion.",
                "dias": [{"id": 3, "descripcion": "Martes"}],
                "icono": "logo_comafi.png",
            },
            "Digital",
            __import__("datetime").date(2026, 9, 8),
            "2026-09-08T00:00:00+00:00",
        )

        self.assertEqual(row.percentage, 30)
        self.assertEqual(row.refund_cap, 15000)
        self.assertEqual(row.weekdays, [2])
        self.assertIn("Banco Comafi", row.compatible_entities)

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
