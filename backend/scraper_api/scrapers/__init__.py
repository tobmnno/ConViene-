from .stores import CarrefourScraper, CotoScraper, LaGallegaScraper

SCRAPERS = {
	"carrefour": CarrefourScraper(),
	"coto": CotoScraper(),
	"la_gallega": LaGallegaScraper(),
}

STORE_NAMES = tuple(SCRAPERS.keys())
