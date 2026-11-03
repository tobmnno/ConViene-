from .stores import CarrefourScraper, CotoScraper, JumboScraper, LaGallegaScraper, LaReinaScraper

SCRAPERS = {
	"carrefour": CarrefourScraper(),
	"coto": CotoScraper(),
	"la_gallega": LaGallegaScraper(),
	"jumbo": JumboScraper(),
	"lareina": LaReinaScraper(),
}

STORE_NAMES = tuple(SCRAPERS.keys())
