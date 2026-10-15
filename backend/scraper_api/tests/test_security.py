import os
import sys
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fastapi.testclient import TestClient
from api import app
from models import EquivalentsResponse, Product, SearchMatch
from services.scraper import SearchQueryResult
from services.images import ImageProxyError, MAX_IMAGE_BYTES, fetch_image, validate_image_url
from services.refresh import RefreshInProgress
from services.monitoring import _safe_detail

TEST_ADMIN_KEY = "test-admin-key-with-at-least-24-chars"


class FakeResponse:
    def __init__(self, status=200, headers=None, data=b"\xff\xd8\xffimage"):
        self.status_code = status
        self.headers = headers or {"content-type": "image/jpeg"}
        self.data = data
        self.is_redirect = status in {301, 302, 303, 307, 308}

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return None

    def raise_for_status(self):
        if self.status_code >= 400:
            import requests
            raise requests.HTTPError("upstream failed")

    def iter_content(self, chunk_size):
        yield self.data


class FakeSession:
    def __init__(self, *responses):
        self.responses = iter(responses)
        self.calls = []
        self.trust_env = True

    def get(self, url, **kwargs):
        self.calls.append((url, kwargs))
        return next(self.responses)

    def close(self):
        pass


class ImageSecurityTests(unittest.TestCase):
    def test_rejects_unlisted_private_and_malformed_destinations(self):
        for url in ("http://127.0.0.1/a", "http://169.254.169.254/a", "file:///etc/passwd",
                    "https://coto.com.ar.evil.test/a", "https://user:pass@coto.com.ar/a",
                    "https://coto.com.ar:9000/a"):
            with self.subTest(url=url), self.assertRaises(ImageProxyError):
                validate_image_url(url)
        with patch("services.images.socket.getaddrinfo", return_value=[(2, 1, 0, "", ("10.0.0.1", 443))]):
            with self.assertRaises(ImageProxyError) as result:
                validate_image_url("https://static.cotodigital3.com.ar/a.jpg")
        self.assertEqual(result.exception.status_code, 403)

    def test_allows_store_cdn_and_follows_only_valid_redirects(self):
        public_dns = [(2, 1, 0, "", ("8.8.8.8", 443))]
        session = FakeSession(FakeResponse(302, {"location": "https://carrefourar.vteximg.com.br/a.jpg"}),
                              FakeResponse())
        with patch("services.images.socket.getaddrinfo", return_value=public_dns), patch("services.images.requests.Session", return_value=session):
            content, mime = fetch_image("https://www.carrefour.com.ar/photo")
        self.assertEqual((content, mime), (b"\xff\xd8\xffimage", "image/jpeg"))
        self.assertEqual(len(session.calls), 2)
        self.assertFalse(session.trust_env)
        self.assertFalse(session.calls[0][1]["allow_redirects"])

    def test_redirect_to_local_or_unlisted_host_never_gets_fetched(self):
        public_dns = [(2, 1, 0, "", ("8.8.8.8", 443))]
        session = FakeSession(FakeResponse(302, {"location": "http://127.0.0.1/private"}))
        with patch("services.images.socket.getaddrinfo", return_value=public_dns), patch("services.images.requests.Session", return_value=session):
            with self.assertRaises(ImageProxyError):
                fetch_image("https://www.coto.com.ar/a")
        self.assertEqual(len(session.calls), 1)

    def test_rejects_wrong_type_and_oversized_image(self):
        public_dns = [(2, 1, 0, "", ("8.8.8.8", 443))]
        for response, status in ((FakeResponse(headers={"content-type": "text/html"}), 415),
                                 (FakeResponse(headers={"content-type": "image/png", "content-length": str(MAX_IMAGE_BYTES + 1)}), 413),
                                 (FakeResponse(headers={"content-type": "image/png"}, data=b"x" * (MAX_IMAGE_BYTES + 1)), 413)):
            with self.subTest(status=status), patch("services.images.socket.getaddrinfo", return_value=public_dns), patch("services.images.requests.Session", return_value=FakeSession(response)):
                with self.assertRaises(ImageProxyError) as result:
                    fetch_image("https://www.lagallega.com.ar/a")
                self.assertEqual(result.exception.status_code, status)

    def test_rejects_html_mislabeled_as_image(self):
        session = FakeSession(FakeResponse(data=b"<html>not an image</html>"))
        with patch("services.images.socket.getaddrinfo", return_value=[(2, 1, 0, "", ("8.8.8.8", 443))]), patch("services.images.requests.Session", return_value=session):
            with self.assertRaises(ImageProxyError) as result:
                fetch_image("https://www.coto.com.ar/a.jpg")
        self.assertEqual(result.exception.status_code, 415)

    def test_network_failure_is_a_gateway_error(self):
        import requests
        session = FakeSession()
        with patch("services.images.socket.getaddrinfo", return_value=[(2, 1, 0, "", ("8.8.8.8", 443))]), patch("services.images.requests.Session", return_value=session), patch.object(session, "get", side_effect=requests.Timeout):
            with self.assertRaises(ImageProxyError) as result:
                fetch_image("https://www.coto.com.ar/a")
        self.assertEqual(result.exception.status_code, 502)


class MonitoringSecurityTests(unittest.TestCase):
    def test_redacts_urls_and_secrets_from_diagnostics(self):
        detail = _safe_detail("timeout https://example.com/item?token=private key=private password:abc")
        self.assertNotIn("private", detail)
        self.assertNotIn("example.com", detail)
        self.assertIn("timeout", detail)


class ApiSecurityTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def tearDown(self):
        self.client.close()

    def test_image_proxy_preserves_error_codes_and_accepts_valid_image(self):
        with patch("api.fetch_image", return_value=(b"ok", "image/png")):
            response = self.client.get("/image", params={"url": "https://www.coto.com.ar/a.jpg"})
        self.assertEqual((response.status_code, response.content), (200, b"ok"))
        with patch("api.fetch_image", side_effect=ImageProxyError(403, "blocked")):
            self.assertEqual(self.client.get("/image", params={"url": "https://www.coto.com.ar/a.jpg"}).status_code, 403)

    def test_admin_refresh_fails_closed_and_checks_key(self):
        with patch("api._development", False), patch.dict(os.environ, {"CONVIENE_ADMIN_KEY": ""}):
            self.assertEqual(self.client.post("/operations/promotions/refresh").status_code, 503)
            self.assertEqual(self.client.get("/operations").status_code, 503)
        with patch("api._development", False), patch.dict(os.environ, {"CONVIENE_ADMIN_KEY": "weak"}):
            self.assertEqual(self.client.post("/operations/promotions/refresh", headers={"X-Admin-Key": "weak"}).status_code, 503)
        with patch.dict(os.environ, {"CONVIENE_ADMIN_KEY": TEST_ADMIN_KEY}):
            self.assertEqual(self.client.post("/operations/promotions/refresh").status_code, 403)
            self.assertEqual(self.client.get("/operations").status_code, 403)
            self.assertEqual(self.client.get("/operations", headers={"X-Admin-Key": TEST_ADMIN_KEY}).status_code, 200)
            with patch("api.refresh_lagallega_catalog", return_value={"checked_at": "now", "benefits": []}):
                response = self.client.post("/operations/promotions/refresh", headers={"X-Admin-Key": TEST_ADMIN_KEY})
            self.assertEqual(response.status_code, 200)
        self.assertNotIn("monitoring", self.client.get("/health").json())

    def test_admin_refresh_returns_conflict_when_another_worker_owns_lock(self):
        with patch.dict(os.environ, {"CONVIENE_ADMIN_KEY": TEST_ADMIN_KEY}), patch(
            "api.refresh_lagallega_catalog", side_effect=RefreshInProgress()
        ):
            response = self.client.post("/operations/promotions/refresh", headers={"X-Admin-Key": TEST_ADMIN_KEY})
        self.assertEqual(response.status_code, 409)

    def test_root_version_and_production_cors(self):
        self.assertEqual(self.client.get("/").json()["version"], app.version)
        response = self.client.options("/search", headers={"Origin": "https://unlisted.example", "Access-Control-Request-Method": "GET"})
        self.assertNotIn("access-control-allow-origin", response.headers)

    def test_equivalents_http_contract_keeps_alternatives_separate(self):
        alternative = SearchMatch(
            product=Product(store="carrefour", name="Dulce de leche otra marca 400 g",
                            price=1999, scraped_at="2026-10-15T12:00:00Z"),
            score=72, normalized_query="dulce de leche", normalized_name="dulce de leche otra marca",
            match_type="alternative",
        )
        payload = EquivalentsResponse(results=[], alternatives=[alternative],
                                      store_status={"carrefour": "not_found"}, checked_at="2026-10-15T12:00:00Z")
        with patch("api.find_equivalents", new_callable=AsyncMock, return_value=payload):
            response = self.client.post("/products/equivalents", json={"product": {"name": "Dulce de leche 400 g"}, "stores": ["carrefour"]})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["results"], [])
        self.assertEqual(response.json()["alternatives"][0]["match_type"], "alternative")
        self.assertEqual(response.json()["store_status"]["carrefour"], "not_found")

    def test_search_http_contract_marks_partial_and_failed_sources(self):
        product = Product(store="coto", name="Leche entera 1 L", price=2000,
                          scraped_at="2026-10-15T12:00:00Z")
        with patch("api._search_catalogs", new_callable=AsyncMock, return_value=SearchQueryResult(
            [product], {"coto": "ok", "carrefour": "error"}
        )):
            response = self.client.get("/search", params={"q": "leche entera", "stores": ["coto", "carrefour"]})
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["partial"])
        self.assertEqual(response.json()["store_status"], {"coto": "found", "carrefour": "error"})

        with patch("api._search_catalogs", new_callable=AsyncMock, return_value=SearchQueryResult(
            [], {"coto": "error", "carrefour": "error"}
        )):
            response = self.client.get("/search", params={"q": "leche entera", "stores": ["coto", "carrefour"]})
        self.assertEqual(response.json()["store_status"], {"coto": "error", "carrefour": "error"})
        self.assertEqual(response.json()["results"], [])

    def test_invalid_barcode_is_rejected_without_scraping(self):
        with patch("api.scrape_query_with_status", new_callable=AsyncMock) as scrape:
            get_response = self.client.get("/search", params={"q": "779089500829"})
            post_response = self.client.post("/search", json={"query": "779089500829"})
        self.assertEqual(get_response.status_code, 422)
        self.assertEqual(post_response.status_code, 422)
        self.assertIn("Codigo de barras invalido", get_response.json()["detail"])
        scrape.assert_not_awaited()

    def test_barcode_reports_exact_product_without_purchasable_offer(self):
        unavailable = Product(store="carrefour", name="Alfajor Guaymallen triple 70 g",
                              ean="77980267", price=785, available=False,
                              scraped_at="2026-10-15T12:00:00Z")
        unrelated = Product(store="coto", name="Otro alfajor", ean="7790895000829",
                            price=500, available=True, scraped_at="2026-10-15T12:00:00Z")
        with patch("api._search_catalogs", new_callable=AsyncMock, return_value=SearchQueryResult(
            [unavailable, unrelated], {"coto": "ok", "carrefour": "ok"}
        )):
            response = self.client.get("/search", params={"q": "77980267", "stores": ["coto", "carrefour"]})
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["results"], [])
        self.assertEqual(payload["store_status"], {"coto": "not_found", "carrefour": "unavailable"})
        self.assertEqual([item["ean"] for item in payload["unavailable_products"]], ["77980267"])


class SearchRetryStatusTests(unittest.IsolatedAsyncioTestCase):
    async def test_successful_retry_replaces_initial_source_error(self):
        from api import _build_search_response, _search_catalogs

        with patch("api.extract_measurement", return_value=(400, "g")), patch(
            "api.reference_queries", return_value=["dulce leche 400g"]
        ), patch(
            "api.scrape_query_with_status",
            new_callable=AsyncMock,
            side_effect=[
                SearchQueryResult([], {"coto": "error"}),
                SearchQueryResult([], {"coto": "ok"}),
            ],
        ):
            result = await _search_catalogs("dulce de leche 400 gramos", ["coto"], 20, "camoufox", {})

        response = _build_search_response("dulce de leche 400 gramos", ["coto"], result.rows, 20,
                                          source_status=result.source_status)
        self.assertEqual(response.store_status, {"coto": "not_found"})
        self.assertFalse(response.partial)


class RefreshConcurrencyTests(unittest.IsolatedAsyncioTestCase):
    async def test_second_refresh_is_rejected_while_first_runs(self):
        from fastapi import HTTPException
        from starlette.requests import Request
        from api import refresh_promotions
        request = Request({"type": "http", "client": ("127.0.0.1", 1234), "method": "POST", "path": "/operations/promotions/refresh", "headers": []})
        started = __import__("asyncio").Event()
        release = __import__("asyncio").Event()

        async def slow_thread(*_args, **_kwargs):
            started.set()
            await release.wait()
            return {"checked_at": "now", "benefits": []}

        with patch.dict(os.environ, {"CONVIENE_ADMIN_KEY": TEST_ADMIN_KEY}), patch("api.asyncio.to_thread", side_effect=slow_thread):
            task = __import__("asyncio").create_task(refresh_promotions(request, TEST_ADMIN_KEY))
            await started.wait()
            with self.assertRaises(HTTPException) as result:
                await refresh_promotions(request, TEST_ADMIN_KEY)
            self.assertEqual(result.exception.status_code, 409)
            release.set()
            await task
