import json
import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from models import DiscountPromotion, DiscountsResponse, Product, SearchResponse
from api import _build_search_response
from scrapers.base import parse_price
from services.catalog import (
    extract_measurement,
    products_are_comparable,
    rank_search_results,
    search_query_for_product_name,
    sort_results_for_output,
)
from services.discounts import (
    _carrefour_payment_requirements,
    _coto_from_api,
    _entities_from_text,
    _lagallega_promotions_from_html,
    _static_promotions,
)
from services.locations import nearby_coto_branches
from services.scraper import resolve_stores


class ContractTest(unittest.TestCase):
    def test_barcode_search_returns_only_matching_gtin(self):
        common = {"store": "coto", "price": 1200, "scraped_at": "2026-10-09T00:00:00+00:00"}
        matched = Product(name="Leche entera La Serenisima", ean="7790742448309", **common)
        other = Product(name="Leche multidefensas La Serenisima", ean="7790742348302", **common)
        response = _build_search_response("7790742448309", ["coto"], [other, matched], 20)
        self.assertEqual([match.product.ean for match in response.results], ["7790742448309"])
        self.assertEqual(response.results[0].match_type, "exact")

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

    def test_nearby_branch_directory_orders_by_distance(self):
        original = os.environ.get("CONVIENE_COTO_BRANCHES_JSON")
        try:
            os.environ["CONVIENE_COTO_BRANCHES_JSON"] = json.dumps([
                {"id": "far", "name": "Coto Norte", "latitude": -32.90, "longitude": -60.70},
                {"id": "near", "name": "Coto Centro", "latitude": -32.95, "longitude": -60.65},
            ])
            suggestions = nearby_coto_branches(-32.95, -60.65)
        finally:
            if original is None:
                os.environ.pop("CONVIENE_COTO_BRANCHES_JSON", None)
            else:
                os.environ["CONVIENE_COTO_BRANCHES_JSON"] = original

        self.assertEqual([row["id"] for row in suggestions], ["near", "far"])
        self.assertEqual(suggestions[0]["distance_km"], 0.0)

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

    def test_double_cream_is_not_the_plain_cream_requested(self):
        rows = [
            Product(store="coto", name="Crema De Leche LA PAULINA 200cc", price=2640, scraped_at="x"),
            Product(store="la_gallega", name="crema de leche la paulina pote x 200 cc doble", price=2400, scraped_at="x"),
        ]

        ranked = rank_search_results("crema la paulina 200cc", rows)

        self.assertEqual([match.match_type for match in ranked], ["exact", "similar"])

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
        self.assertEqual(row.required_entity_groups, [["Visa"], ["Banco Comafi"]])

    def test_coto_modo_and_bank_require_both_entities(self):
        row = _coto_from_api(
            {
                "id": "367",
                "textoDescuento": "35% DE DESCUENTO",
                "descripcion": "Pagando con MODO desde la app de Comafi con tarjetas del banco",
                "icono": "logo_comafi2.png",
                "dias": [{"id": 3, "descripcion": "Martes"}],
            },
            "Sucursal",
            __import__("datetime").date(2026, 10, 6),
            "2026-10-06T00:00:00+00:00",
        )

        self.assertEqual(row.required_entity_groups, [["MODO"], ["Banco Comafi"]])

    def test_coto_card_brands_remain_alternatives_with_required_bank(self):
        row = _coto_from_api(
            {
                "id": "409",
                "textoDescuento": "12 CUOTAS SIN INTERES",
                "descripcion": "Con tarjetas Visa y Mastercard del Banco Comafi",
                "dias": [{"id": 3, "descripcion": "Martes"}],
            },
            "Digital",
            __import__("datetime").date(2026, 10, 6),
            "2026-10-06T00:00:00+00:00",
        )

        self.assertEqual(row.required_entity_groups, [["Visa", "Mastercard"], ["Banco Comafi"]])

    def test_entity_detection_does_not_find_nacion_inside_iluminacion(self):
        entities = _entities_from_text(
            "Productos de iluminacion con tarjetas Visa y Mastercard logo_macro_bma3.png"
        )

        self.assertEqual(entities, ["Visa", "Mastercard", "Banco Macro"])

    def test_coto_naranja_x_visa_requires_naranja_x(self):
        row = _coto_from_api(
            {
                "id": "382",
                "textoDescuento": "30% DE DESCUENTO",
                "descripcion": "Con tarjeta de credito Naranja X o Debito Naranja X VISA",
                "dias": [{"id": 3, "descripcion": "Martes"}],
            },
            "Digital",
            __import__("datetime").date(2026, 10, 13),
            "2026-10-13T00:00:00+00:00",
        )

        self.assertEqual(row.compatible_entities, ["Naranja X"])

    def test_lagallega_bank_card_offer_requires_both(self):
        rows = _lagallega_promotions_from_html(
            "<div>30% descuento con tarjetas Visa y Mastercard de Banco Santa Fe.</div>",
            __import__("datetime").date(2026, 10, 13),
            "2026-10-13T00:00:00+00:00",
        )

        self.assertEqual(len(rows), 1)
        self.assertEqual(
            rows[0].required_entity_groups,
            [["Visa", "Mastercard"], ["Banco Santa Fe"]],
        )

    def test_carrefour_exclusive_modo_offer_requires_issuer_and_card(self):
        entities, groups = _carrefour_payment_requirements(
            "5% de ahorro con tarjetas Visa y Mastercard. Exclusivo pagando con Modo.",
            "Tarjetas emitidas por el Banco Nacion a traves de Modo o BNA+.",
            ["Visa", "Mastercard", "MODO"],
        )

        self.assertEqual(entities, ["Visa", "Mastercard", "MODO", "Banco Nacion"])
        self.assertEqual(
            groups,
            [["MODO"], ["Visa", "Mastercard"], ["Banco Nacion"]],
        )

    def test_static_promotions_keep_weekday_and_minimum_purchase(self):
        covered, rows = _static_promotions(
            "carrefour",
            __import__("datetime").date(2026, 9, 9),
        )

        self.assertTrue(covered)
        self.assertTrue(rows)
        self.assertTrue(any(row.start_date == "2026-01-01" for row in rows))
        self.assertTrue(any(row.end_date == "2026-12-31" for row in rows))
        monthly_campaigns = [row for row in rows if row.start_date == "2026-09-01"]
        self.assertTrue(monthly_campaigns)
        self.assertTrue(all(row.end_date == "2026-09-30" for row in monthly_campaigns))
        self.assertTrue(all(3 in row.weekdays for row in rows))
        mercado_pago = next(row for row in rows if row.minimum_purchase == 150000)
        self.assertEqual(mercado_pago.entity, "Mercado Pago")
        self.assertIn("wallet", mercado_pago.compatible_payment_types)
        self.assertIn("card", mercado_pago.compatible_payment_types)

    def test_static_lagallega_catalog_uses_current_explicit_validity(self):
        expired_covered, expired_rows = _static_promotions(
            "la_gallega", __import__("datetime").date(2026, 9, 26)
        )
        covered, rows = _static_promotions(
            "la_gallega",
            __import__("datetime").date(2026, 10, 2),
        )

        self.assertTrue(covered)
        self.assertTrue(expired_covered)
        self.assertEqual(expired_rows, [])
        self.assertEqual(len(rows), 3)
        cuenta_dni = next(row for row in rows if row.entity == "Cuenta DNI" and row.percentage == 30)
        self.assertEqual(cuenta_dni.weekdays, [4, 5])
        self.assertEqual(cuenta_dni.end_date, "2027-01-01")
        santa_fe = next(row for row in rows if row.entity == "Banco Santa Fe")
        self.assertEqual(santa_fe.end_date, "2026-12-31")

        monday_covered, monday_rows = _static_promotions(
            "la_gallega", __import__("datetime").date(2026, 10, 19)
        )
        self.assertTrue(monday_covered)
        modo_rows = [row for row in monday_rows if row.entity == "MODO" and row.percentage == 25]
        self.assertEqual(len(modo_rows), 2)
        self.assertEqual({row.title for row in modo_rows}, {
            "MODO (Visa Signature) - 25% OFF",
            "MODO (Mastercard) - 25% OFF",
        })
        self.assertEqual(
            {tuple(tuple(group) for group in row.required_entity_groups) for row in modo_rows},
            {(('MODO',), ('Visa',)), (('MODO',), ('Mastercard',))},
        )

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
