# Conviene

Aplicacion movil Flutter para comparar precios entre supermercados argentinos y calcular donde conviene comprar un producto o todo el changuito, aplicando descuentos segun medios de pago.

Supermercados integrados:

- https://www.lagallega.com.ar/
- https://www.coto.com.ar/
- https://www.carrefour.com.ar/

## App Flutter

```powershell
cd "C:\Users\6to\Documents\ChatGPT\conviene 2"
flutter run -d chrome
```

La app intenta usar por defecto la API real en `http://127.0.0.1:8000`. Si la API no esta levantada, cae al repositorio mock para que la interfaz siga funcionando.

## Backend real

El backend integrado vive en:

```text
C:\Users\6to\Documents\ChatGPT\conviene 2\backend\scraper_api
```

Para instalarlo y levantarlo:

```powershell
cd "C:\Users\6to\Documents\ChatGPT\conviene 2\backend\scraper_api"
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m camoufox fetch
.\.venv\Scripts\python.exe -m uvicorn api:app --host 127.0.0.1 --port 8000 --reload
```

En esta maquina la `.venv` ya fue recreada con Python 3.14 y las dependencias quedaron instaladas. Tambien quedo instalado Camoufox.

Pruebas rapidas:

```powershell
Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:8000/health"
Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:8000/search?q=leche%20entera%201l&limit=3&stores=coto"
```

Mas detalles en `backend/scraper_api/README.md`.
