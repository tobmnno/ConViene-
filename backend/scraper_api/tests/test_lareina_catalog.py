import unittest
from unittest.mock import patch

from scrapers.lagallega_catalog import CatalogPage
from scrapers.stores import _lareina_api_search
from services.discounts import scrape_discounts
from services.scraper import resolve_stores


SAMPLE = '''
<li class="cuadProd">
  <a href="productosdet.asp?Pr=7790742358608&amp;P=1">
    <img src="Fotos/Articulos/7790742358608.jpg" alt="Leche" />
  </a>
  <div class="precio"><div class="izq">$2.614,<b>00</b></div></div>
  <div class="desc">leche c/ protein uat bot la serenisima 1 lt</div>
</li>
'''


class LaReinaCatalogTest(unittest.TestCase):
    def test_public_card_keeps_official_image_link_and_ean(self):
        page = CatalogPage(SAMPLE, base_url="https://www.lareinaonline.com.ar/")
        self.assertEqual(len(page.rows), 1)
        row = page.rows[0]
        self.assertEqual(row["ean"], "7790742358608")
        self.assertEqual(row["price"], 2614)
        self.assertTrue(row["image"].startswith("https://www.lareinaonline.com.ar/"))
        self.assertTrue(row["url"].startswith("https://www.lareinaonline.com.ar/productosdet.asp"))

    def test_bad_internal_identifier_is_not_treated_as_barcode(self):
        page = CatalogPage(SAMPLE.replace("7790742358608", "0000000020546"),
                           base_url="https://www.lareinaonline.com.ar/")
        self.assertIsNone(page.rows[0]["ean"])

    def test_failed_page_is_not_confirmed_absence(self):
        with patch("scrapers.stores.read_catalog_page", return_value=None):
            self.assertIsNone(_lareina_api_search("leche", 5))

    def test_no_unverified_bank_discount_is_calculated(self):
        self.assertEqual(resolve_stores(["La Reina"]), ["lareina"])
        response = scrape_discounts(["lareina"])
        self.assertEqual(response.results, [])
        self.assertTrue(response.warnings)


if __name__ == "__main__":
    unittest.main()
