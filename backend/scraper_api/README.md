# Conviene Scraper API

Backend local para que la app Flutter busque precios reales en:

- https://www.lagallega.com.ar/
- https://www.coto.com.ar/
- https://www.carrefour.com.ar/

La API corre en `http://127.0.0.1:8000` y la app Conviene ya apunta a ese puerto por defecto.

## 1. Instalar

Desde PowerShell:

```powershell
cd "C:\Users\6to\Documents\ChatGPT\conviene 2\backend\scraper_api"
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m camoufox fetch
```

Si no tenes Python 3.13, usa Python 3.12. Python 3.14 puede funcionar, pero si alguna dependencia falla, 3.13/3.12 suele ser la opcion mas estable.

Tambien podes hacer doble clic en `INSTALAR_WINDOWS.bat`.

## 2. Levantar la API

Desde PowerShell:

```powershell
cd "C:\Users\6to\Documents\ChatGPT\conviene 2\backend\scraper_api"
.\.venv\Scripts\python.exe -m uvicorn api:app --host 127.0.0.1 --port 8000 --reload
```

O doble clic en `INICIAR_BACKEND.bat`.

Deja esa terminal abierta mientras usas la app.

## 3. Probar

Abri en el navegador:

```text
http://127.0.0.1:8000/health
http://127.0.0.1:8000/search?q=leche&stores=coto&stores=carrefour&stores=la_gallega
```

La app tambien acepta `lagallega`, pero el backend lo normaliza internamente como `la_gallega`.

## Endpoints

- `GET /health`: estado y supermercados disponibles.
- `GET /stores`: supermercados del backend y IDs usados por la app.
- `GET /search?q=leche&stores=coto&stores=carrefour`: busqueda rapida.
- `POST /search`: busqueda con JSON `query`, `limit` y `stores`.
- `POST /compare`: comparacion de changuito con productos y cantidades.

## Contrato de busqueda

`GET /search` devuelve:

```json
{
  "query": "leche",
  "stores": ["coto", "carrefour", "la_gallega"],
  "count": 1,
  "results": [
    {
      "score": 98.4,
      "product": {
        "store": "la_gallega",
        "name": "leche entera armonia 2 % sachet x 1 litro",
        "price": 2006.0,
        "url": "https://www.lagallega.com.ar/",
        "image": null,
        "available": true,
        "scraped_at": "2026-08-27T12:00:00+00:00"
      },
      "normalized_query": "leche",
      "normalized_name": "leche entera armonia sachet"
    }
  ]
}
```

Conviene consume ese formato directamente y cae al mock si el backend no esta levantado.
