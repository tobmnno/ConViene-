import sys
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from models import EquivalentsRequest, Product, ProductReference
from scrapers.stores import _carrefour_api_search, _coto_price, _lagallega_api_search, _offer_for_vtex_product
from scrapers.lagallega_catalog import CatalogPage
from services.catalog import alternative_match, extract_measurement, same_catalog_product, valid_gtin
from services.equivalents import _cache, _inflight, find_equivalents, reference_queries
from api import _build_search_response


def product(name, ean=None, **fields):
    return Product(store="coto", name=name, ean=ean, price=2000, scraped_at="2026-10-02T00:00:00Z", **fields)


class IdentityTests(unittest.TestCase):
    def test_bare_condom_count_rejects_another_pack_size(self):
        self.assertEqual(extract_measurement("Preservativos ultrafinos 6"), (6.0, "unit"))
        self.assertFalse(same_catalog_product(
            ProductReference(name="Preservativos Tulipan ultrafinos 6"),
            product("Preservativos Ultrafinos Tulipan Bli 1 Uni"),
        ))

    def test_coffee_creamer_is_not_instant_coffee(self):
        from services.catalog import products_are_comparable

        self.assertFalse(products_are_comparable(
            "cafe instantaneo 170g", "cafe instantaneo nestle coffee mate x 170 gr",
        ))

    def test_same_brand_classic_and_traditional_are_same_only_with_identity_evidence(self):
        reference = ProductReference(name="Dulce de leche clasico Coto 400 g", brand="Coto")
        same = product("Dulce de leche tradicional Coto 400 gramos", brand="Coto")
        self.assertTrue(same_catalog_product(reference, same))
        self.assertFalse(same_catalog_product(
            ProductReference(name="Dulce de leche clasico 400 g"),
            product("Dulce de leche tradicional 400 gr"),
        ))

    def test_other_brand_is_alternative_never_identical(self):
        reference = ProductReference(name="Dulce de leche clasico Coto 400 g", brand="Coto")
        other = product("Dulce de leche tradicional Carrefour 400gr", brand="Carrefour")
        self.assertFalse(same_catalog_product(reference, other))
        self.assertEqual(alternative_match(reference, other).match_type, "alternative")
        for name in ("Dulce de leche repostero Carrefour 400 g",
                     "Dulce de leche tradicional Carrefour 1 kg",
                     "Crema de leche tradicional Carrefour 400 g"):
            self.assertIsNone(alternative_match(reference, product(name, brand="Carrefour")))

    def test_composite_food_is_not_a_dulce_de_leche_alternative(self):
        reference = ProductReference(name="Dulce de leche La Paulina 200 gr", brand="La Paulina")
        for name in ("Arroz con leche con dulce de leche Tregar 180 Grm",
                     "Alfajor con dulce de leche Tregar 200 gr",
                     "Helado de dulce de leche Tregar 200 gr"):
            with self.subTest(name=name):
                self.assertIsNone(alternative_match(reference, product(name, brand="Tregar")))
        self.assertEqual(extract_measurement("Dulce Leche Clasico Milkaut Pot 245 Grm"), (245.0, "g"))
        self.assertIsNone(alternative_match(
            reference, product("Dulce Leche Clasico Milkaut Pot 245 Grm", brand="Milkaut")
        ))

    def test_alternatives_keep_condom_model_quantity_and_incomplete_data_separate(self):
        reference = ProductReference(name="Preservativos Tulipan superfino 6 u", brand="Tulipan")
        self.assertEqual(alternative_match(
            reference, product("Preservativos Maxx superfino 6 unidades", brand="Maxx")
        ).match_type, "alternative")
        self.assertIsNone(alternative_match(
            reference, product("Preservativos Maxx texturado 6 u", brand="Maxx")
        ))
        self.assertIsNone(alternative_match(
            reference, product("Preservativos Maxx superfino 12 u", brand="Maxx")
        ))
        self.assertEqual(alternative_match(
            reference, product("Preservativos Maxx 6 u", brand="Maxx")
        ).match_type, "review")

    def test_limited_search_preserves_a_match_from_each_store(self):
        rows = [product("Leche La Serenisima 1 L") for _ in range(10)]
        other = product("Leche La Serenisima 1 L")
        other.store, other.price = "la_gallega", 9999
        rows.append(other)
        response = _build_search_response("leche serenisima 1 L", ["coto", "la_gallega"], rows, 3)
        self.assertEqual(response.count, 3)
        self.assertEqual({match.product.store for match in response.results}, {"coto", "la_gallega"})

    def test_full_catalog_reads_gtin_discount_and_pagination(self):
        page = CatalogPage('''<li class="cuadProd"><div class="FotoProd">
          <a href="productosdet.asp?Pr=21495"><img src="Fotos/Articulos/21495.jpg"
             alt="7790742363107 - leche larga vida la serenisima 1 % x 1 litro"></a></div>
          <div class="InfoProd"><div class="desc">leche larga vida la serenisima 1 % x 1 litro</div>
          <div class="precio"><div class="izqdes">$2.838,0</div><div class="der"><b>$2.559,0</b></div></div>
          <div class="BotonAgrega">Agregar</div></div></li>
          <a onclick="window.location.href='productosnl.asp?pg=2&amp;TM=Bus';">2</a>''')
        self.assertEqual(page.rows[0]["ean"], "7790742363107")
        self.assertEqual(page.rows[0]["price"], 2559)
        self.assertEqual(page.rows[0]["regular_price"], 2838)
        self.assertEqual(page.pages, {2})
        self.assertEqual(page.rows[0]["url"], "https://www.lagallega.com.ar/productosdet.asp?Pr=21495")

    def test_official_milk_names_share_gtin_despite_missing_descriptors(self):
        reference = ProductReference(name="Leche La Serenisima liviana 1% 1L", ean="7790742363107")
        for name in ["Leche Larga Vida Parcialmente Descremada Liviana 1% La Serenisima 1l",
                     "Leche larga vida la serenisima 1 % x 1 litro"]:
            self.assertTrue(same_catalog_product(reference, product(name, "7790742363107")))

    def test_different_gtins_cannot_be_equal_from_similar_names(self):
        reference = ProductReference(name="Leche Las 3 Ninas 200 ml", ean="7798338291933")
        self.assertFalse(same_catalog_product(reference, product("Leche Las 3 Ninas 200 ml", "7798338291629")))

    def test_invalid_gtin_does_not_override_conflicting_size(self):
        reference = ProductReference(name="Crema La Paulina 200 cc", ean="1234567890123")
        self.assertIsNone(valid_gtin(reference.ean))
        self.assertFalse(same_catalog_product(reference, product("Crema La Paulina 350 ml", reference.ean)))

    def test_matching_gtin_does_not_override_explicit_size_or_variant_conflicts(self):
        reference = ProductReference(name="Leche La Serenisima liviana 1% 1 L", ean="7790742363107")
        self.assertFalse(same_catalog_product(
            reference, product("Leche La Serenisima liviana 1% 1.5 L", reference.ean)
        ))
        self.assertFalse(same_catalog_product(
            reference, product("Leche La Serenisima entera 3% 1 L", reference.ean)
        ))

    def test_same_gtin_accepts_catalog_marketing_names_and_abbreviations(self):
        pairs = [
            ("Leche Multidefensas 1% LA SERENISIMA Sachet 1l",
             "Leche La Serenísima ultra parc descremada multivit 1% sachet 1 lt",
             "7790742348005"),
            ("Leche Multidefensas 1% LA SERENISIMA Sachet 1l",
             "leche la serenisima descremada x1l sachet md", "7790742348005"),
            ("Leche con Prebióticos La Serenisima 1L",
             "leche larga vida la serenisima con prebioticos x 1", "7790742358509"),
            ("LA SERENISIMA 100% Vegetal Almendra 1l",
             "Alimento bebible a base de almendras La Serenísima 1 l",
             "7790742340108"),
            ("Galletitas OREO Golden Sabor Vainilla Rellenas Con Crema 354g",
             "galletitas oreo golden x 354 gr", "7622201806538"),
        ]
        for name, other, ean in pairs:
            with self.subTest(ean=ean):
                self.assertTrue(same_catalog_product(
                    ProductReference(name=name, ean=ean), product(other, ean)
                ))

    def test_weight_takes_precedence_over_unit_count_in_catalog_name(self):
        name = "Galletitas OREO Bañadas En Chocolate Blanco X 7 Unidades 119g"
        self.assertEqual(extract_measurement(name), (119, "g"))
        self.assertTrue(same_catalog_product(
            ProductReference(name=name, ean="7622201745608"),
            product("Galletitas Oreo bañadas en chocolate blanco x7 119 g.", "7622201745608"),
        ))

    def test_same_gtin_still_rejects_hard_variant_and_quantity_conflicts(self):
        reference = ProductReference(name="Leche La Serenisima 1% multidefensas 1 L", ean="7790742348005")
        self.assertFalse(same_catalog_product(
            reference, product("Leche La Serenisima 2% multivit 1 L", reference.ean)
        ))
        self.assertFalse(same_catalog_product(
            reference, product("Leche La Serenisima 1% multivit 1.5 L", reference.ean)
        ))
        self.assertFalse(same_catalog_product(
            ProductReference(name="Galletitas Oreo bañadas chocolate blanco 119 g", ean="7622201745608"),
            product("Galletitas Oreo rellenas chocolate blanco 119 g", "7622201745608"),
        ))
        self.assertFalse(same_catalog_product(
            ProductReference(name="Preservativos Tulipan ultrafinos 1 uni", ean="7791014121906"),
            product("Preservativos Tulipan ultrafinos 6 u", "7791014121906"),
        ))

    def test_unrequested_special_formulas_and_compound_types_are_rejected(self):
        reference = ProductReference(name="Leche Las Tres Ninas entera 200 ml")
        for name in ["Leche Las 3 Ninas primeros anos entera 200 ml",
                     "Crema leche Las 3 Ninas entera 200 ml",
                     "Leche Las 3 Ninas entera proteina 200 ml",
                     "Leche Las 3 Ninas entera chocolatada 200 ml",
                     "Leche Las 3 Ninas entera pack 2 x 100 ml"]:
            self.assertFalse(same_catalog_product(reference, product(name)), name)

    def test_unidentified_milk_cannot_gain_an_unrequested_formula(self):
        reference = ProductReference(name="Leche La Serenisima entera 1 L")
        for variant in ["sin lactosa", "barista", "protein", "extra calcio",
                        "colageno", "con hierro", "multidefensas"]:
            self.assertFalse(same_catalog_product(reference,
                product(f"Leche La Serenisima entera 1 L {variant}")), variant)

    def test_missing_percentage_is_not_guessed_without_a_gtin(self):
        reference = ProductReference(name="Leche La Serenisima liviana 1% 1 L")
        self.assertFalse(same_catalog_product(reference, product("Leche La Serenisima liviana 1 L")))
        self.assertTrue(same_catalog_product(reference, product("Leche larga vida La Serenisima 1% 1 L")))

    def test_brand_numeric_alias_and_legacy_units(self):
        reference = ProductReference(name="Leche Las 3 Ninas entera 200 ml")
        self.assertTrue(same_catalog_product(reference, product("Leche Las Tres Ninas entera 200 cc")))
        self.assertEqual(extract_measurement("Galletitas Oreo 118 gm"), (118, "g"))

    def test_condom_unit_aliases_match_without_mixing_models(self):
        reference = ProductReference(
            name="Preservativos Sup/Fino TULIPAN Bli 6 Uni", brand="TULIPAN"
        )
        self.assertEqual(extract_measurement(reference.name), (6, "unit"))
        self.assertTrue(same_catalog_product(
            reference, product("Preservativos Tulipán super fino 6 u", brand="TULIPAN")
        ))
        self.assertTrue(same_catalog_product(
            reference, product("PRESERVATIVO TULIPAN SUPERFINO X6", brand="TULIPAN")
        ))
        self.assertFalse(same_catalog_product(
            reference, product("Preservativos Tulipán texturado 6 u", brand="TULIPAN")
        ))
        self.assertFalse(same_catalog_product(
            reference, product("Preservativos Tulipán super fino 3 u", brand="TULIPAN")
        ))
        self.assertFalse(same_catalog_product(
            reference, product("Preservativos Maxx super fino 6 u", brand="MAXX")
        ))

    def test_common_catalog_name_variations_and_distinct_products(self):
        equivalent_names = [
            ("Galletitas Oreo chocolate 118 g", "Galletita Oreo chocolate 118 gr"),
            ("Fideos Matarazzo tirabuzon 500 g", "Fideo Matarazzo tirabuzon 500gr"),
            ("Dulce de leche La Paulina 400 g", "Dulce La Paulina de leche 400gr"),
            ("Crema La Paulina 200 cc", "Crema de leche La Paulina 200 ml"),
            ("Yerba Taragui sin palo 1 kg", "Yerba Taragui sin palo 1000 g"),
            ("Preservativos Tulipan super fino 6 uni", "PRESERVATIVO TULIPAN SUPERFINO X6"),
        ]
        different_names = [
            ("Crema La Paulina 200 cc", "Crema La Paulina 350 cc"),
            ("Galletitas Oreo chocolate 3 x 118 g", "Galletitas Oreo chocolate 354 g"),
            ("Galletitas Oreo frutilla 118 g", "Galletitas Oreo chocolate 118 g"),
            ("Dulce de leche La Paulina 400 g", "Dulce de leche Vacalin 400 g"),
            ("Preservativos Tulipan super fino 6 uni", "Preservativos Tulipan texturado 6 u"),
            ("Preservativos Tulipan super fino 6 uni", "Preservativos Tulipan super fino 3 u"),
        ]
        for reference_name, candidate_name in equivalent_names:
            with self.subTest(reference=reference_name, candidate=candidate_name):
                self.assertTrue(same_catalog_product(
                    ProductReference(name=reference_name), product(candidate_name)
                ))
        for reference_name, candidate_name in different_names:
            with self.subTest(reference=reference_name, candidate=candidate_name):
                self.assertFalse(same_catalog_product(
                    ProductReference(name=reference_name), product(candidate_name)
                ))

    def test_queries_keep_brand_and_content_without_long_marketing_name(self):
        reference = ProductReference(name="Leche La Serenisima liviana 1% 1L", ean="7790742363107", brand="La Serenisima")
        self.assertEqual(reference_queries(reference)[:2], ["7790742363107", "leche serenisima 1"])
        self.assertEqual(
            reference_queries(ProductReference(name="Dulce de leche La Paulina 200 gr", brand="La Paulina")),
            ["dulce de leche paulina 200", "Dulce de leche La Paulina 200 gr", "dulce de leche paulina"],
        )
        self.assertEqual(reference_queries(ProductReference(name="%%%")), ["%%%"])
        self.assertEqual(
            reference_queries(ProductReference(name="Preservativos Sup/Fino TULIPAN Bli 6 Uni", brand="TULIPAN"))[:1],
            ["preservativo tulipan 6"],
        )
        self.assertEqual(
            reference_queries(ProductReference(name="Preservativos Sup/Fino TULIPAN Bli 6 Uni"))[:1],
            ["preservativo tulipan 6"],
        )

    def test_coto_never_uses_another_branch_price(self):
        self.assertEqual(_coto_price({"price": [{"store": "401", "listPrice": 1234}]}, "200"), (None, None))
        self.assertEqual(_coto_price({"price": [{"store": "200", "listPrice": 1234}]}, "200"), (1234, None))

    def test_vtex_prefers_an_available_seller_over_stale_offer(self):
        stale = {"Price": 1, "IsAvailable": False}
        current = {"Price": 2000, "IsAvailable": True}
        _, offer = _offer_for_vtex_product({"items": [{"sellers": [{"commertialOffer": stale}, {"commertialOffer": current}]}]})
        self.assertEqual(offer, current)

    def test_carrefour_filters_by_ean_and_prices_the_matching_sku(self):
        other = {"ean": "7790895064142", "sellers": [{"commertialOffer": {"Price": 100, "IsAvailable": True}}]}
        selected = {"ean": "7790895000829", "sellers": [{"commertialOffer": {"Price": 1900, "IsAvailable": True}}]}
        with patch("scrapers.stores.requests.get") as get:
            get.return_value.status_code = 200
            get.return_value.json.return_value = [{
                "productName": "Gaseosa Sprite 500 ml", "items": [other, selected],
            }]
            rows = _carrefour_api_search("7790895000829", 20)

        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0].ean, rows[0].price), ("7790895000829", 1900))
        self.assertEqual(get.call_args.kwargs["params"]["fq"], "alternateIds_Ean:7790895000829")

    def test_lagallega_uses_barcode_autocomplete_instead_of_text_catalog(self):
        row = product("Gaseosa Sprite 500 ml", "7790895000829")
        with patch("scrapers.stores._lagallega_autocomplete_search", return_value=[row]) as autocomplete:
            self.assertEqual(_lagallega_api_search("7790895000829", 20), [row])
        autocomplete.assert_called_once_with("7790895000829", 20, None)


class EquivalentsTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _cache.clear()
        _inflight.clear()

    def request(self):
        return EquivalentsRequest(product={"name": "Leche La Serenisima liviana 1% 1L", "ean": "7790742363107"}, stores=["coto"])

    async def test_exact_gtin_stops_fallback_queries_and_is_cached(self):
        search = AsyncMock(return_value=[product("Leche La Serenisima 1% 1L", "7790742363107")])
        with patch("services.equivalents._search_one_direct_store", search):
            result = await find_equivalents(self.request())
            await find_equivalents(self.request())
        self.assertEqual(result.store_status, {"coto": "found"})
        self.assertEqual(result.results[0].score, 100)
        self.assertEqual(search.await_count, 1)

    async def test_gtin_fast_path_rejects_conflicting_size(self):
        search = AsyncMock(return_value=[
            product("Leche La Serenisima liviana 1% 1.5 L", "7790742363107")
        ])
        with patch("services.equivalents._search_one_direct_store", search):
            result = await find_equivalents(self.request())
        self.assertEqual(result.results, [])
        self.assertEqual(result.store_status, {"coto": "not_found"})

    async def test_broad_fallback_finds_exact_size_without_accepting_other_brands(self):
        request = EquivalentsRequest(
            product={"name": "Dulce de leche La Paulina 200 gr", "brand": "La Paulina"},
            stores=["coto"],
        )
        async def search(_store, query, _limit, _context):
            if query == "dulce de leche paulina":
                return [
                    product("Dulce de leche Vacalin 200 gr", brand="Vacalin"),
                    product("Dulce La Paulina de leche 400 gr", brand="La Paulina"),
                    product("Dulce La Paulina de leche 200 gr", brand="La Paulina"),
                ]
            return []
        with patch("services.equivalents._search_one_direct_store", side_effect=search) as mock:
            result = await find_equivalents(request)
        self.assertEqual(result.store_status, {"coto": "found"})
        self.assertEqual(result.results[0].product.name, "Dulce La Paulina de leche 200 gr")
        self.assertEqual(mock.await_count, 3)

    async def test_transient_partial_failure_is_retried_before_reporting_error(self):
        attempts = {}
        async def search(_store, query, _limit, _context):
            attempts[query] = attempts.get(query, 0) + 1
            if query == "leche serenisima 1":
                return None if attempts[query] == 1 else [
                    product("Leche La Serenisima liviana 1% 1L", "7790742363107")
                ]
            return []
        with patch("services.equivalents._search_one_direct_store", side_effect=search):
            result = await find_equivalents(self.request())
        self.assertEqual(result.store_status, {"coto": "found"})
        self.assertEqual(attempts["leche serenisima 1"], 2)

    async def test_partial_failure_does_not_claim_out_of_stock(self):
        async def search(_store, query, _limit, _context):
            if query == "leche serenisima 1":
                return None
            return [product("Leche La Serenisima liviana 1% 1L", "7790742363107", available=False)]
        with patch("services.equivalents._search_one_direct_store", side_effect=search):
            result = await find_equivalents(self.request())
        self.assertEqual(result.store_status, {"coto": "error"})

    async def test_failure_is_not_cached_or_reported_as_absence(self):
        search = AsyncMock(return_value=None)
        with patch("services.equivalents._search_one_direct_store", search):
            result = await find_equivalents(self.request())
            await find_equivalents(self.request())
        self.assertEqual(result.store_status, {"coto": "error"})
        self.assertEqual(search.await_count, 6)
        self.assertEqual(result.results, [])

    async def test_stock_is_distinct_from_no_catalog_match(self):
        search = AsyncMock(return_value=[product("Leche La Serenisima 1% 1L", "7790742363107", available=False)])
        with patch("services.equivalents._search_one_direct_store", search):
            result = await find_equivalents(self.request())
        self.assertEqual(result.store_status, {"coto": "unavailable"})
        self.assertEqual(result.results, [])
        _cache.clear()
        with patch("services.equivalents._search_one_direct_store", AsyncMock(return_value=[])):
            result = await find_equivalents(self.request())
        self.assertEqual(result.store_status, {"coto": "not_found"})

    async def test_stale_ean_stock_checks_name_results_before_marking_unavailable(self):
        stale = product("Preservativo Maxx super fino 6 uni", "7798171946489", available=False)
        current = product("Preservativos Super Fino Maxx 6 u", "7798171946489")
        search = AsyncMock(side_effect=[[stale], [current], [current]])
        request = EquivalentsRequest(
            product={
                "name": "Preservativos Super Fino Maxx Cja 6 Uni",
                "ean": "7798171946489",
                "brand": "MAXX",
            },
            stores=["coto"],
        )
        with patch("services.equivalents._search_one_direct_store", search):
            result = await find_equivalents(request)
        self.assertEqual(result.store_status, {"coto": "found"})
        self.assertEqual(result.results[0].product.ean, "7798171946489")

    async def test_cache_is_scoped_to_branch(self):
        search = AsyncMock(return_value=[])
        with patch("services.equivalents._search_one_direct_store", search):
            await find_equivalents(self.request())
            request = self.request()
            request.context.coto_store = "401"
            await find_equivalents(request)
        self.assertEqual(search.await_count, 10)

    async def test_alternative_is_separate_from_verified_results_and_status(self):
        request = EquivalentsRequest(
            product={"name": "Dulce de leche clasico Coto 400 g", "brand": "Coto"},
            stores=["carrefour"],
        )
        search = AsyncMock(return_value=[product(
            "Dulce de leche tradicional Carrefour 400gr", brand="Carrefour"
        )])
        with patch("services.equivalents._search_one_direct_store", search):
            response = await find_equivalents(request)
        self.assertEqual(response.results, [])
        self.assertEqual(response.store_status, {"carrefour": "not_found"})
        self.assertEqual(response.alternatives[0].match_type, "alternative")

    async def test_concurrent_calls_share_work_and_release_inflight_on_failure(self):
        import asyncio
        request = self.request()
        calls = 0

        async def find(*_args):
            nonlocal calls
            calls += 1
            await asyncio.sleep(0.01)
            return None, "not_found", []

        with patch("services.equivalents._find_in_store", side_effect=find):
            results = await asyncio.gather(*(find_equivalents(request) for _ in range(8)))
        self.assertEqual(calls, 1)
        self.assertTrue(all(result.store_status == {"coto": "not_found"} for result in results))
        self.assertEqual(_inflight, {})

    async def test_error_does_not_leave_inflight_key(self):
        with patch("services.equivalents._find_in_store", AsyncMock(side_effect=RuntimeError("failed"))):
            with self.assertRaises(RuntimeError):
                await find_equivalents(self.request())
        self.assertEqual(_inflight, {})
        self.assertEqual(_cache, {})
