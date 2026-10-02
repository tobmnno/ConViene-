import asyncio
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from html import unescape
import re
from urllib.parse import quote, urljoin

try:
    from playwright.async_api import Page
except Exception:
    from typing import Any

    Page = Any

import requests

from models import Product
from .base import BaseScraper, parse_price
from .lagallega_catalog import read_catalog_page


REQUEST_HEADERS = {
    "Accept": "application/json,text/html;q=0.9,*/*;q=0.8",
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
    ),
}

DIRECT_HTTP_TIMEOUT_SECONDS = 12


async def search_via_box(page: Page, base_url: str, query: str):
    await page.goto(base_url, wait_until="domcontentloaded", timeout=60000)
    candidates = [
        'input[type="search"]',
        'input[placeholder*="Buscar" i]',
        'input[placeholder*="Que queres comprar" i]',
        'input[placeholder*="Que estas buscando" i]',
        'input[placeholder*="Qué querés comprar" i]',
        'input[placeholder*="Qué estás buscando" i]',
        'input[name*="search" i]',
        'input[id*="search" i]',
        'input[aria-label*="search" i]',
        '#cio-autocomplete-0-input',
        '#cpoBuscar',
        '#cpoBuscarMovil',
    ]
    for selector in candidates:
        box = page.locator(selector).first
        try:
            if await box.count() and await box.is_visible(timeout=1200):
                await box.fill(query)
                submit = page.locator(
                    'button[aria-label*="Submit Search" i], button[aria-label*="Buscar" i], input[type="submit"], button:has-text("Buscar")'
                ).first
                if await submit.count() and await submit.is_visible(timeout=1200):
                    await submit.click()
                else:
                    await box.press("Enter")
                await page.wait_for_load_state("networkidle", timeout=30000)
                await page.wait_for_timeout(3000)
                return True
        except Exception:
            pass
    return False


async def extract_results(scraper: BaseScraper, page: Page, limit: int):
    results = (await scraper.extract_jsonld(page, limit)) or (await scraper.extract_cards(page, limit))
    if results:
        return results
    return await scraper.extract_text_products(page, limit)


def _offer_for_vtex_product(product: dict):
    fallback = (None, None)
    for item in product.get("items") or []:
        for seller in item.get("sellers") or []:
            offer = seller.get("commertialOffer") or {}
            if offer.get("Price") is not None:
                if offer.get("IsAvailable") and offer.get("Price", 0) > 0:
                    return item, offer
                fallback = (item, offer)
    return fallback


def _image_for_vtex_item(item: dict | None):
    if not item:
        return None
    images = item.get("images") or []
    if not images:
        return None
    return images[0].get("imageUrl")


def _carrefour_api_search(query: str, limit: int, context: dict | None = None):
    encoded = quote(query)
    response = requests.get(
        f"https://www.carrefour.com.ar/api/catalog_system/pub/products/search/{encoded}",
        params={"_from": 0, "_to": max(limit - 1, 0), "sc": (context or {}).get("carrefour_sales_channel", "1")},
        headers=REQUEST_HEADERS,
        timeout=DIRECT_HTTP_TIMEOUT_SECONDS,
    )
    if response.status_code not in {200, 206}:
        return None

    rows = []
    for raw_product in response.json()[:limit]:
        item, offer = _offer_for_vtex_product(raw_product)
        if not offer:
            continue
        price = offer.get("Price")
        try:
            price = float(price)
        except (TypeError, ValueError):
            continue
        list_price = offer.get("ListPrice")
        try:
            list_price = float(list_price) if list_price is not None else None
        except (TypeError, ValueError):
            list_price = None
        rows.append(
            Product(
                store="carrefour",
                name=str(raw_product.get("productName") or raw_product.get("productTitle") or "").strip(),
                ean=str((item or {}).get("ean") or "") or None,
                brand=raw_product.get("brand"),
                price=price,
                regular_price=list_price if list_price and list_price > price else None,
                promo_text="; ".join((raw_product.get("productClusters") or {}).values())[:500] or None,
                unit=(item or {}).get("measurementUnit") if item else None,
                url=raw_product.get("link"),
                image=_image_for_vtex_item(item),
                available=offer.get("IsAvailable", True) is not False,
                branch_id=f"sales-channel-{(context or {}).get('carrefour_sales_channel', '1')}",
                pricing_scope="online_sales_channel",
                delivery_available=offer.get("IsAvailable", True) is not False if (context or {}).get("fulfillment") == "delivery" else None,
                scraped_at=datetime.now(timezone.utc).isoformat(),
            )
        )
    return [row for row in rows if row.name]


def _coto_query_candidates(query: str):
    normalized = query.lower()
    candidates = [query]
    if "dulce" in normalized and "leche" in normalized:
        candidates.append("dulce de leche")
    if "leche" in normalized and "entera" in normalized:
        candidates.append("leche entera")
    if "leche" in normalized and "descremada" in normalized:
        candidates.append("leche descremada")
    deduped = []
    for candidate in candidates:
        if candidate not in deduped:
            deduped.append(candidate)
    return deduped


def _coto_price(data: dict, store_id: str):
    discounts = data.get("discounts") or []
    for discount in discounts:
        price = parse_price(discount.get("discountPrice"))
        if price is not None:
            return price, parse_price(discount.get("regularPriceText"))

    prices = data.get("price") or []
    preferred = next((item for item in prices if str(item.get("store")) == store_id), None)
    if prices and preferred is None:
        return None, None
    price_row = preferred or {}
    price = price_row.get("listPrice", data.get("product_list_price"))
    try:
        return float(price), None
    except (TypeError, ValueError):
        return None, None


def _coto_api_search(query: str, limit: int, context: dict | None = None):
    store_id = str((context or {}).get("coto_store") or "200")
    had_response = False
    candidates = [query] if (context or {}).get("equivalence_search") else _coto_query_candidates(query)
    for candidate in candidates:
        response = requests.get(
            "https://api.coto.com.ar/api/v1/ms-digital-sitio-bff-web/api/v1/products/search/"
            + quote(candidate),
            params={
                "key": "key_r6xzz4IAoTWcipni",
                "num_results_per_page": str(limit),
                "pre_filter_expression": '{"name":"store_availability","value":"' + store_id + '"}',
                "c": "cio-fe-web-coto-conviene",
                "us": store_id,
            },
            headers=REQUEST_HEADERS,
            timeout=DIRECT_HTTP_TIMEOUT_SECONDS,
        )
        if response.status_code != 200:
            continue

        had_response = True
        rows = []
        for result in (response.json().get("response") or {}).get("results") or []:
            data = result.get("data") or {}
            price, regular_price = _coto_price(data, store_id)
            if price is None:
                continue
            product_url = data.get("url")
            rows.append(
                Product(
                    store="coto",
                    name=str(result.get("value") or data.get("sku_display_name") or "").strip(),
                    ean=str(data.get("product_main_ean") or "") or None,
                    brand=data.get("product_brand"),
                    price=price,
                    regular_price=regular_price,
                    promo_text=", ".join(
                        discount.get("discountText", "")
                        for discount in data.get("discounts") or []
                        if discount.get("discountText")
                    )
                    or None,
                    unit=data.get("product_unit_of_measure"),
                    url=f"https://www.coto.com.ar/productos{product_url}" if product_url else "https://www.coto.com.ar/",
                    image=data.get("image_url") or data.get("product_large_image_url") or data.get("product_medium_image_url"),
                    available=store_id in [str(store) for store in data.get("store_availability") or [store_id]],
                    branch_id=store_id,
                    pricing_scope="selected_store",
                    delivery_available=None,
                    scraped_at=datetime.now(timezone.utc).isoformat(),
                )
            )
        if rows:
            return rows[:limit]
    return [] if had_response else None


def _clean_html_text(value: str | None):
    if not value:
        return ""
    text = re.sub(r"<[^>]+>", " ", value)
    text = unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def _lagallega_suggestions(session: requests.Session, query: str, limit: int):
    session.get(
        "https://www.lagallega.com.ar/",
        headers=REQUEST_HEADERS,
        timeout=DIRECT_HTTP_TIMEOUT_SECONDS,
    )
    response = session.get(
        "https://www.lagallega.com.ar/ProdAutoCompleta.asp",
        params={"cB": query, "cF": "FormBus"},
        headers=REQUEST_HEADERS,
        timeout=DIRECT_HTTP_TIMEOUT_SECONDS,
    )
    if response.status_code != 200:
        return None
    if "AutoCompItem" not in response.text:
        return None if "top.location.href" in response.text else []

    pattern = re.compile(
        r"EnvioForm\('Det','Pr=(?P<id>\d+)'\).*?"
        r"<img\s+src=\"(?P<image>[^\"]+)\"[^>]*alt=\"(?P<alt>[^\"]*)\".*?"
        r"<div class=\"AutoCompTxt AutoCompDesc\">(?P<name>.*?)</div>.*?"
        r"<div class=\"AutoCompTxt AutoCompCod\">(?P<ean>.*?)</div>",
        re.IGNORECASE | re.DOTALL,
    )
    rows = []
    seen = set()
    for match in pattern.finditer(response.text):
        product_id = match.group("id")
        if product_id in seen:
            continue
        seen.add(product_id)
        rows.append(
            {
                "id": product_id,
                "name": _clean_html_text(match.group("name") or match.group("alt")),
                "image": urljoin("https://www.lagallega.com.ar/", match.group("image")),
                "ean": _clean_html_text(match.group("ean")),
            }
        )
        if len(rows) >= limit:
            break
    return rows


def _lagallega_detail(session: requests.Session | None, product_id: str):
    url = f"https://www.lagallega.com.ar/productosdet.asp?Pr={product_id}"
    getter = session.get if session is not None else requests.get
    response = getter(url, headers=REQUEST_HEADERS, timeout=15)
    if response.status_code != 200:
        return None
    detail_html = response.text
    price_match = re.search(r"DetallPrec.*?(\$\s*[\d.,]+)", detail_html, re.IGNORECASE | re.DOTALL)
    name_match = re.search(r"<div class=\"DetallDesc\"><b>(.*?)</b>", detail_html, re.IGNORECASE | re.DOTALL)
    image_match = re.search(r"data-image=\"([^\"]+)\"", detail_html, re.IGNORECASE)
    return {
        "name": _clean_html_text(name_match.group(1)) if name_match else "",
        "price": parse_price(price_match.group(1) if price_match else None),
        "image": urljoin("https://www.lagallega.com.ar/", image_match.group(1)) if image_match else "",
        "url": url,
    }


def _lagallega_autocomplete_search(query: str, limit: int, context: dict | None = None):
    with requests.Session() as session:
        suggestions = _lagallega_suggestions(session, query, limit)
        if suggestions is None:
            return None
        if not suggestions:
            return []
        worker_count = min(6, len(suggestions))
        with ThreadPoolExecutor(max_workers=worker_count) as executor:
            details = list(
                executor.map(
                    lambda suggestion: _lagallega_detail(None, suggestion["id"]),
                    suggestions,
                )
            )
        rows = []
        for suggestion, raw_detail in zip(suggestions, details):
            detail = raw_detail or {}
            price = detail.get("price")
            if price is None:
                continue
            name = detail.get("name") or suggestion["name"]
            rows.append(
                Product(
                    store="la_gallega",
                    name=name.title(),
                    ean=suggestion["ean"] or None,
                    price=price,
                    unit=None,
                    url=detail.get("url") or f"https://www.lagallega.com.ar/productosdet.asp?Pr={suggestion['id']}",
                    image=detail.get("image") or suggestion["image"],
                    available=True,
                    pricing_scope="catalog_no_branch",
                    delivery_available=None,
                    scraped_at=datetime.now(timezone.utc).isoformat(),
                )
            )
        return rows[:limit]


def _lagallega_api_search(query: str, limit: int, context: dict | None = None):
    with requests.Session() as session:
        session.get("https://www.lagallega.com.ar/", headers=REQUEST_HEADERS,
                    timeout=DIRECT_HTTP_TIMEOUT_SECONDS)
        first = read_catalog_page(session, query, 1, REQUEST_HEADERS, DIRECT_HTTP_TIMEOUT_SECONDS)
        if first is None:
            return None
        rows = list(first.rows)
        if rows and len(rows) < limit:
            needed_pages = (limit + len(rows) - 1) // len(rows)
            for page in sorted(first.pages):
                if page <= 1 or page > min(needed_pages, 5) or len(rows) >= limit:
                    continue
                following = read_catalog_page(session, query, page, REQUEST_HEADERS, DIRECT_HTTP_TIMEOUT_SECONDS)
                if following is None:
                    # A truncated catalog must not become a confirmed absence.
                    return None
                rows.extend(following.rows)
        unique = {}
        for row in rows:
            unique[row["url"]] = Product(
                store="la_gallega", **row, available=None,
                pricing_scope="catalog_no_branch",
                scraped_at=datetime.now(timezone.utc).isoformat(),
            )
        return list(unique.values())[:limit]


class CarrefourScraper(BaseScraper):
    store = "carrefour"
    base_url = "https://www.carrefour.com.ar/"

    async def search_direct(self, query: str, limit: int = 30, context: dict | None = None):
        return await asyncio.to_thread(_carrefour_api_search, query, limit, context)

    async def search(self, page: Page, query: str, limit: int = 30):
        api_results = await self.search_direct(query, limit)
        if api_results:
            return api_results

        encoded = quote(query)
        for url in [
            f"{self.base_url}{encoded}?_q={encoded}&map=ft",
            f"{self.base_url}search?ft={encoded}",
        ]:
            await page.goto(url, wait_until="domcontentloaded", timeout=60000)
            await self.accept_cookies(page)
            await page.wait_for_timeout(4500)
            results = await extract_results(self, page, limit)
            if results:
                return results
        return []


class CotoScraper(BaseScraper):
    store = "coto"
    base_url = "https://www.coto.com.ar/"

    async def search_direct(self, query: str, limit: int = 30, context: dict | None = None):
        return await asyncio.to_thread(_coto_api_search, query, limit, context)

    async def search(self, page: Page, query: str, limit: int = 30):
        api_results = await self.search_direct(query, limit)
        if api_results:
            return api_results

        encoded = quote(query)
        for url in [
            f"{self.base_url}productos/{encoded}",
            f"{self.base_url}buscar?Ntt={encoded}",
        ]:
            await page.goto(url, wait_until="domcontentloaded", timeout=60000)
            await self.accept_cookies(page)
            await page.wait_for_timeout(4500)
            results = await extract_results(self, page, limit)
            if results:
                return results
        return []


class LaGallegaScraper(BaseScraper):
    store = "la_gallega"
    base_url = "https://www.lagallega.com.ar/"

    async def search_direct(self, query: str, limit: int = 30, context: dict | None = None):
        return await asyncio.to_thread(_lagallega_api_search, query, limit, context)

    async def search(self, page: Page, query: str, limit: int = 30):
        api_results = await self.search_direct(query, limit)
        if api_results:
            return api_results

        found_box = await search_via_box(page, self.base_url, query)
        if not found_box:
            await page.goto(f"{self.base_url}Articulos.asp", wait_until="domcontentloaded", timeout=60000)
        await self.accept_cookies(page)
        await page.wait_for_timeout(4500)
        return await extract_results(self, page, limit)
