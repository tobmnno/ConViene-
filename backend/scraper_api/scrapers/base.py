import json
import re
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urljoin

try:
    from playwright.async_api import Page
except Exception:
    Page = Any

from models import Product

PRICE_RE = re.compile(r"(?:\$\s*)?(\d[\d\.]*(?:,\d{1,2})?|\d+(?:\.\d{1,2})?)")


def parse_price(text: str | None):
    if not text:
        return None
    match = PRICE_RE.search(text.replace("\xa0", " "))
    if not match:
        return None
    raw = match.group(1).strip()
    if "," in raw:
        normalized = raw.replace(".", "").replace(",", ".")
    elif raw.count(".") > 1:
        normalized = raw.replace(".", "")
    elif "." in raw:
        left, right = raw.split(".", 1)
        normalized = raw if len(right) <= 2 and len(left) <= 4 else raw.replace(".", "")
    else:
        normalized = raw
    try:
        return float(normalized)
    except ValueError:
        return None


class BaseScraper(ABC):
    store: str
    base_url: str

    @abstractmethod
    async def search(self, page: Page, query: str, limit: int = 30) -> list[Product]: ...

    async def accept_cookies(self, page: Page):
        for label in ["Aceptar", "Acepto", "Aceptar todas", "Entendido"]:
            try:
                btn = page.get_by_role("button", name=re.compile(label, re.I)).first
                if await btn.is_visible(timeout=700):
                    await btn.click()
            except Exception:
                pass

    async def extract_jsonld(self, page: Page, limit: int):
        rows = []
        scripts = await page.locator('script[type="application/ld+json"]').all_text_contents()

        def walk(obj):
            if isinstance(obj, dict):
                if obj.get("@type") == "Product":
                    rows.append(obj)
                for v in obj.values():
                    walk(v)
            elif isinstance(obj, list):
                for v in obj:
                    walk(v)

        for raw in scripts:
            try:
                walk(json.loads(raw))
            except Exception:
                continue
        out = []
        for x in rows[:limit]:
            offers = x.get("offers") or {}
            if isinstance(offers, list):
                offers = offers[0] if offers else {}
            out.append(
                Product(
                    store=self.store,
                    name=str(x.get("name") or "").strip(),
                    price=parse_price(str(offers.get("price"))),
                    url=urljoin(self.base_url, x.get("url") or ""),
                    image=(x.get("image") or [None])[0] if isinstance(x.get("image"), list) else x.get("image"),
                    scraped_at=datetime.now(timezone.utc).isoformat(),
                )
            )
        return [p for p in out if p.name]

    async def extract_cards(self, page: Page, limit: int):
        selectors = [
            'div.vtex-product-summary-2-x-container--contentProduct',
            'div.vtex-product-summary-2-x-element--contentProduct',
            'div.categoria-producto',
            'li.categoria-producto',
            'article',
            '[data-testid*="product"]',
            '[class*="product-card"]',
            '[class*="productCard"]',
            'li[class*="product"]',
        ]
        cards = None
        for s in selectors:
            loc = page.locator(s)
            if await loc.count() >= 2:
                cards = loc
                break
        if cards is None:
            return []
        out = []
        for i in range(min(await cards.count(), limit)):
            c = cards.nth(i)
            try:
                text = (await c.inner_text()).strip()
                price = parse_price(text)
                if not price:
                    continue
                name = ""
                for ns in ['h2', 'h3', 'h4', '[class*="name"]', '[class*="title"]', 'a[title]']:
                    n = c.locator(ns).first
                    if await n.count():
                        name = ((await n.get_attribute('title')) or (await n.inner_text())).strip()
                        if name:
                            break
                if not name:
                    name = next((z.strip() for z in text.splitlines() if z.strip() and '$' not in z), '')
                a = c.locator('a[href]').first
                href = await a.get_attribute('href') if await a.count() else None
                img = c.locator('img').first
                src = (await img.get_attribute('src')) if await img.count() else None
                out.append(
                    Product(
                        store=self.store,
                        name=name,
                        price=price,
                        promo_text=text[:500],
                        url=urljoin(self.base_url, href or ''),
                        image=urljoin(self.base_url, src or '') if src else None,
                        scraped_at=datetime.now(timezone.utc).isoformat(),
                    )
                )
            except Exception:
                continue
        return out

    async def extract_text_products(self, page: Page, limit: int):
        body_text = await page.locator("body").inner_text()
        lines = [ln.strip() for ln in body_text.replace("\xa0", " ").splitlines() if ln.strip()]
        rows = []
        current_name = []

        skip_names = {
            "ofertas",
            "marca",
            "categoría",
            "categorias",
            "contenido",
            "tipo de corte",
            "tipo de carne",
            "potencia",
            "tiempo de garantía",
            "también te podría interesar",
            "lo más relevante",
            "más",
            "nombre de a a z",
            "precio: de menor a mayor",
            "precio: de mayor a menor",
            "agregar",
            "ver planes de cuotas",
            "seleccioná un carrito de compra",
        }

        def looks_like_product_name(value: str):
            lowered = value.lower()
            if not value or len(value) <= 2 or lowered in skip_names:
                return False
            if any(token in lowered for token in ["ver precio", "precio sin impuestos", "aplicar", "filtros", "relevancia", "productos", "carrito", "ingresar", "ofertas"]):
                return False
            return bool(re.search(r"[a-zA-ZáéíóúÁÉÍÓÚñÑ]", value))

        for index, line in enumerate(lines):
            lowered = line.lower()
            if line.startswith("Precio") or line.startswith("Ver") or line.startswith("Agregar"):
                continue
            if "$" in line:
                price = parse_price(line)
                if not price:
                    continue
                name = " ".join(current_name).strip()
                if not name:
                    for lookahead in lines[index + 1 : index + 6]:
                        if looks_like_product_name(lookahead):
                            name = lookahead
                            break
                if len(name) > 2 and len(name) < 220 and lowered not in skip_names:
                    rows.append(
                        Product(
                            store=self.store,
                            name=name,
                            price=price,
                            promo_text=line[:500],
                            url=self.base_url,
                            image=None,
                            scraped_at=datetime.now(timezone.utc).isoformat(),
                        )
                    )
                current_name = []
                if len(rows) >= limit:
                    break
                continue
            if lowered in skip_names:
                current_name = []
                continue
            if len(line) <= 2:
                continue
            if re.search(r"\d+\s*(?:kg|g|ml|lt|l\b)", line, flags=re.I):
                current_name.append(line)
                continue
            if any(keyword in lowered for keyword in ["leche", "yogur", "queso", "arroz", "cerveza", "yerba", "aceite", "dulce", "gallet", "coca", "harina", "pan", "salsa", "detergente", "jugo", "agua", "papas", "pollo", "pescado"]):
                current_name.append(line)
                continue
            if current_name and len(current_name) < 3:
                current_name.append(line)

        dedup = []
        seen = set()
        for row in rows:
            key = (row.name.strip().lower(), row.price)
            if key in seen:
                continue
            seen.add(key)
            dedup.append(row)
        return dedup[:limit]
