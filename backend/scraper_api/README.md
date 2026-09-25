# Conviene Scraper API

Backend FastAPI de Conviene. Consulta precios, imagenes y promociones publicas
de Coto, Carrefour Argentina y La Gallega, y expone un contrato comun para la
aplicacion Flutter.

## Responsabilidades

- Consultar los tres supermercados en paralelo.
- Usar APIs directas cuando estan disponibles.
- Utilizar Camoufox o Chromium como respaldo para contenido dinamico.
- Normalizar precios, nombres, unidades, packs y disponibilidad.
- Puntuar resultados por relevancia.
- Comparar productos equivalentes entre comercios.
- Obtener promociones y validar su vigencia.
- Servir imagenes mediante un proxy con cache.
- Mantener una cache corta de busquedas y descuentos.

## Requisitos

- Python 3.12 o 3.13 recomendado.
- Conexion a Internet.
- Windows, macOS o Linux. Los scripts `.bat` son exclusivos de Windows.

## Instalacion

Desde la carpeta `backend/scraper_api`:

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m camoufox fetch
```

En Windows tambien se puede ejecutar `INSTALAR_WINDOWS.bat` desde el Explorador
o desde PowerShell:

```powershell
.\INSTALAR_WINDOWS.bat
```

El instalador recrea `.venv`. No debe ejecutarse si se necesita conservar una
virtualenv modificada manualmente.

## Ejecucion

```powershell
.\.venv\Scripts\python.exe -m uvicorn api:app `
  --host 127.0.0.1 `
  --port 8000 `
  --reload
```

En Windows, `INICIAR_BACKEND.bat` ejecuta el mismo servidor. Mantener la
terminal abierta mientras se utiliza Flutter.

Verificacion:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

OpenAPI: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs).

## Endpoints

### `GET /health`

Comprueba el estado de la API y lista los supermercados registrados.

### `GET /stores`

Devuelve los IDs internos del backend y los IDs esperados por Flutter.

### `GET /search`

Parametros:

| Parametro | Requerido | Descripcion |
| --- | --- | --- |
| `q` | Si | Consulta de al menos dos caracteres. |
| `limit` | No | Resultados, entre 1 y 50. Valor por defecto: 20. |
| `stores` | No | Parametro repetible con los supermercados elegidos. |
| `engine` | No | `camoufox` o `chromium`. Valor por defecto: `camoufox`. |

```powershell
Invoke-RestMethod `
  "http://127.0.0.1:8000/search?q=leche%20entera%201l&limit=10&stores=coto&stores=carrefour&stores=la_gallega"
```

Cada resultado incluye el producto original, puntaje de relevancia, consulta
normalizada, nombre normalizado y compatibilidad de tamaño.

### `POST /search`

```json
{
  "query": "dulce de leche 400 g",
  "limit": 20,
  "stores": ["coto", "carrefour", "la_gallega"]
}
```

### `POST /compare`

Busca productos comparables y calcula el total por supermercado.

```json
{
  "items": [
    {"name": "Leche La Serenisima liviana 1 L", "quantity": 2},
    {"name": "Galletitas Oreo 3 x 118 g", "quantity": 1}
  ],
  "limit": 20,
  "stores": ["coto", "carrefour", "la_gallega"]
}
```

El ranking informa productos encontrados, faltantes y total. Una tienda con
productos faltantes no se presenta como una compra completa.

### `GET /discounts`

Parametros:

| Parametro | Requerido | Descripcion |
| --- | --- | --- |
| `date` | No | Fecha ISO `AAAA-MM-DD`. Por defecto utiliza la fecha actual. |
| `stores` | No | Parametro repetible para limitar supermercados. |

```powershell
Invoke-RestMethod `
  "http://127.0.0.1:8000/discounts?date=2026-09-25&stores=coto&stores=la_gallega"
```

La respuesta contiene promociones normalizadas y un arreglo `warnings`. Las
advertencias explican fuentes inaccesibles, contratos inesperados o registros
oficiales con vigencias contradictorias.

### `GET /image`

Proxy de imagenes utilizado por Flutter Web:

```text
GET /image?url=https://dominio-del-supermercado/imagen.jpg
```

Solo acepta URLs HTTP o HTTPS, valida que la respuesta sea una imagen y agrega
cache de navegador por 24 horas.

## Supermercados y alias

| Comercio | ID canonico | Alias aceptados |
| --- | --- | --- |
| Coto | `coto` | `coto` |
| Carrefour | `carrefour` | `carrefour` |
| La Gallega | `la_gallega` | `lagallega`, `la-gallega`, `la gallega` |

Si no se especifican tiendas, se consultan las tres.

## Matching de productos

El catalogo normaliza acentos, ruido comercial, porcentajes, codigos y unidades.
La puntuacion combina similitud de texto, cobertura de palabras, intencion de
busqueda y tamaño.

Para comparar productos se validan ademas:

- Cantidad total en gramos o mililitros.
- Cantidad y tamaño individual de packs.
- Marca o palabras de identidad.
- Sabores y variantes incompatibles.
- Disponibilidad y precio valido.

El margen de tamaño evita diferencias de formato menores, pero rechaza cambios
materiales de presentacion.

## Rendimiento y cache

- Las tiendas se consultan en paralelo.
- Los productos de un changuito se comparan en paralelo.
- Los detalles de La Gallega se descargan con un grupo limitado de workers.
- Las busquedas se almacenan durante 120 segundos.
- Los descuentos se almacenan durante 30 minutos por fecha y conjunto de tiendas.
- Las solicitudes simultaneas identicas comparten el mismo trabajo en curso.

La cache vive en memoria y se elimina al reiniciar el proceso.

## Fuentes de descuentos

- Coto: endpoint oficial de promociones multicanal.
- Carrefour: entidades oficiales de promociones, bancos y tarjetas.
- La Gallega: pagina de beneficios y endpoints por dia o banco.

No se trasladan promociones vencidas a una fecha nueva. Si una fuente conserva
un registro activo con legales vencidos, el registro se omite y se devuelve una
advertencia.

## CLI del scraper

El backend tambien puede utilizarse sin FastAPI:

```powershell
.\.venv\Scripts\python.exe main.py "leche entera" `
  --stores coto carrefour la_gallega `
  --limit 10
```

El resultado se guarda en `output.json`, archivo ignorado por Git. Para mostrar
el navegador durante una prueba se puede agregar `--headed`.

## Pruebas

Desde la raiz del repositorio:

```powershell
.\backend\scraper_api\.venv\Scripts\python.exe `
  -m unittest discover -s backend\scraper_api\tests -q
```

Prueba manual del navegador:

```powershell
cd backend\scraper_api
.\PROBAR_CAMOUFOX.bat
```

Las pruebas `live` dependen de servicios externos y pueden omitirse cuando no
hay conexion o cuando un supermercado cambia temporalmente su sitio.

## Limitaciones

- Los precios pueden variar por sucursal, codigo postal, stock o canal.
- Algunos comercios no publican EAN para todos los productos.
- El matching por nombre reduce errores, pero no reemplaza un catalogo maestro.
- Los sitios pueden modificar endpoints, HTML o mecanismos anti-automatizacion.
- Las promociones dependen de legales externos que pueden publicarse tarde o
  permanecer visibles despues de su vencimiento.
- El servidor incluido esta configurado para desarrollo local, no para una
  exposicion publica sin autenticacion, restricciones de red y observabilidad.

## Integracion con Flutter

Flutter utiliza `CONVIENE_API_BASE_URL` para elegir el backend:

```powershell
flutter run -d chrome `
  --dart-define=CONVIENE_API_BASE_URL=http://127.0.0.1:8000
```

Si la API falla, `ApiRepository` delega en `MockRepository`. Este comportamiento
mantiene la interfaz disponible, pero los datos de respaldo no representan una
consulta actual a los supermercados.
