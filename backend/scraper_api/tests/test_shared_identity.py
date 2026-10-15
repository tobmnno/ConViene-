import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from models import Product, ProductReference
from services.catalog import same_catalog_product


class SharedIdentityTests(unittest.TestCase):
    def test_python_matches_shared_flutter_cases(self):
        fixture = Path(__file__).resolve().parents[3] / "test" / "fixtures" / "product_identity_cases.json"
        for case in json.loads(fixture.read_text(encoding="utf-8")):
            selected, candidate = case["selected"], case["candidate"]
            reference = ProductReference(name=selected["name"], brand=selected["brand"], ean=selected.get("ean"))
            product = Product(store="coto", name=candidate["name"], brand=candidate["brand"],
                              ean=candidate.get("ean"), price=2000, scraped_at="2026-10-15T12:00:00Z")
            with self.subTest(case=case["id"]):
                self.assertEqual(same_catalog_product(reference, product), case["same_product"])
