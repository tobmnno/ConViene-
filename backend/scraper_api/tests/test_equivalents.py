import sys
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from models import EquivalentsRequest, Product, ProductReference
from scrapers.stores import _coto_price, _offer_for_vtex_product
from scrapers.lagallega_catalog import CatalogPage
from services.catalog import extract_measurement, same_catalog_product, valid_gtin
from services.equivalents import _cache, find_equivalents, reference_queries
from api import _build_search_response


def product(name, ean=None, **fields):
    return Product(store="coto", name=name, ean=ean, price=2000, scraped_at="2026-10-02T00:00:00Z", **fields)


class IdentityTests(unittest.TestCase):
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

    def test_queries_keep_brand_and_content_without_long_marketing_name(self):
        reference = ProductReference(name="Leche La Serenisima liviana 1% 1L", ean="7790742363107", brand="La Serenisima")
        self.assertEqual(reference_queries(reference)[:2], ["7790742363107", "leche serenisima 1"])
        self.assertEqual(reference_queries(ProductReference(name="%%%")), ["%%%"])

    def test_coto_never_uses_another_branch_price(self):
        self.assertEqual(_coto_price({"price": [{"store": "401", "listPrice": 1234}]}, "200"), (None, None))
        self.assertEqual(_coto_price({"price": [{"store": "200", "listPrice": 1234}]}, "200"), (1234, None))

    def test_vtex_prefers_an_available_seller_over_stale_offer(self):
        stale = {"Price": 1, "IsAvailable": False}
        current = {"Price": 2000, "IsAvailable": True}
        _, offer = _offer_for_vtex_product({"items": [{"sellers": [{"commertialOffer": stale}, {"commertialOffer": current}]}]})
        self.assertEqual(offer, current)


class EquivalentsTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        _cache.clear()

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

    async def test_cache_is_scoped_to_branch(self):
        search = AsyncMock(return_value=[])
        with patch("services.equivalents._search_one_direct_store", search):
            await find_equivalents(self.request())
            request = self.request()
            request.context.coto_store = "401"
            await find_equivalents(request)
        self.assertEqual(search.await_count, 6)
