import asyncio

from camoufox.async_api import AsyncCamoufox

from scrapers import CarrefourScraper, CotoScraper, LaGallegaScraper


async def main():
    async with AsyncCamoufox(headless=True) as browser:
        ctx = await browser.new_context(
            locale="es-AR",
            timezone_id="America/Argentina/Cordoba",
        )
        for scraper in [CarrefourScraper(), CotoScraper(), LaGallegaScraper()]:
            page = await ctx.new_page()
            try:
                rows = await scraper.search(page, "leche", 3)
                print(f"{scraper.store}: {len(rows)}")
                for row in rows[:3]:
                    print(f"  - {row.name[:90]} | ${row.price}")
            except Exception as exc:  # pragma: no cover - smoke test only
                print(f"{scraper.store}: ERROR {type(exc).__name__}: {exc}")
            finally:
                await page.close()
        await ctx.close()


if __name__ == "__main__":
    asyncio.run(main())
