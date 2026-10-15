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
- Actualizar y auditar el feed de promociones de La Gallega.
- Registrar salud, latencia y errores de las fuentes externas.

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
$env:CONVIENE_ENV = 'development'
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
| `postal_code` | No | Codigo postal argentino de cuatro digitos. |
| `fulfillment` | No | `pickup` o `delivery`. Valor por defecto: `pickup`. |
| `coto_store` | No | Sucursal Coto usada para precio y stock. Valor por defecto: `200`. |
| `carrefour_sales_channel` | No | Canal de venta de Carrefour. Valor por defecto: `1`. |

```powershell
Invoke-RestMethod `
  "http://127.0.0.1:8000/search?q=leche%20entera%201l&limit=10&stores=coto&stores=carrefour&stores=la_gallega"
```

Cada resultado incluye el producto original, puntaje de relevancia, consulta
normalizada, nombre normalizado y compatibilidad de tamaño. Tambien informa
`ean` y `brand` cuando la fuente los publica, ademas de
`branch_id`, `pricing_scope` y, cuando el supermercado lo publica,
`delivery_available`; asi una cotizacion sin sucursal no se presenta como stock
local confirmado.

`store_status` informa `found`, `not_found`, `unavailable` o `error` para cada
tienda consultada. `partial` vale `true` si fallo alguna fuente: se conservan
los productos de las fuentes que respondieron, pero no se interpreta el error
como ausencia del producto. Una busqueda con todas las fuentes fallidas puede
devolver HTTP 200 con `results` vacio y `partial: true`; los clientes deben
consultar `store_status` antes de mostrar "sin resultados". Las respuestas
parciales por error no se guardan en cache.

Si `q` es un GTIN/EAN valido, primero se consulta el codigo exacto en cada
tienda. Carrefour usa su indice de EAN y La Gallega su autocompletado, ademas
de la busqueda de Coto. Si alguna fuente identifica el producto, la respuesta
incluye `identified_product` y el backend busca su nombre, presentacion y
variante en las tiendas sin oferta por EAN. Esas coincidencias se marcan con
`match_type: name_match`; un EAN comprobado conserva `match_type: exact`.
No se hacen conjeturas por nombre si ninguna fuente identifica el codigo.
Un codigo de 8 a 14 digitos con checksum invalido devuelve HTTP 422.
`unavailable_products` enumera los productos identificados por el EAN que no
tienen oferta comprable en el canal consultado; no se incluyen en `results` ni
en los calculos de precios. La ausencia de un EAN en un catalogo no demuestra
que no exista en otras sucursales o canales.

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
Los items admiten `ean` y `brand`, y el cuerpo admite `context` con los mismos
campos de ubicacion y canal que la busqueda. Usa el mismo motor de equivalencias
que el changuito y devuelve `store_status` por item.

```json
{
  "items": [
    {"name": "Leche La Serenisima liviana 1% 1 L", "ean": "7790742363107", "quantity": 2},
    {"name": "Galletitas Oreo 3 x 118 g", "quantity": 1}
  ],
  "limit": 20,
  "stores": ["coto", "carrefour", "la_gallega"]
}
```

El ranking informa productos encontrados, faltantes y total. Una tienda con
productos faltantes no se presenta como una compra completa.
`limit` se conserva en este endpoint por compatibilidad; el motor de
equivalencias devuelve como maximo una oferta verificada por tienda. Los
controles internos `headless` y `engine` tampoco alteran ese motor directo.

### `POST /products/equivalents`

Consulta el mismo producto en las tiendas seleccionadas, sin competir por un
limite global de resultados:

```json
{
  "product": {
    "name": "Leche La Serenisima liviana 1% 1L",
    "ean": "7790742363107",
    "brand": "La Serenisima"
  },
  "stores": ["coto", "carrefour", "la_gallega"],
  "context": {"coto_store": "200", "carrefour_sales_channel": "1"}
}
```

Valida el digito de control del GTIN y prioriza ese identificador sobre las
diferencias de nombres o unidades publicadas. Sin identificador verificable,
aplica las reglas de marca, contenido, packs y variantes. Dos GTIN validos
distintos nunca se consideran equivalentes.

`results` contiene solo productos confirmados: `exact` para GTIN coincidente y
`same_product` para identidad corroborada por atributos. `alternatives` contiene
sugerencias `alternative` o `review`; sus precios no entran en los totales.

`store_status` distingue `found`, `not_found`, `unavailable` y `error`.
`not_found` solo describe el catalogo y contexto consultados; no confirma que
el producto este ausente en todas las sucursales. La respuesta incluye
`checked_at` y una oferta por tienda cuando pudo verificarse.

La cache dura 120 segundos y depende del producto y contexto de compra. Las
respuestas con errores no se cachean. Las consultas directas tienen concurrencia
limitada; La Gallega utiliza las tarjetas de su catalogo paginado, incluyendo
precio de oferta, precio de lista e imagen, sin depender de las 15 sugerencias.

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

Solo acepta dominios oficiales/CDN permitidos, rechaza IP privadas o reservadas
en cada redireccion, valida el tipo de imagen y limita la respuesta a 5 MiB.
Las consultas bloqueantes se ejecutan fuera del event loop. La variable
`CONVIENE_IMAGE_ALLOWED_HOSTS` agrega CDN separados por comas. El navegador
almacena la imagen 24 horas.

### Operacion

- `GET /operations` devuelve estado de cada fuente, latencia, errores recientes
  y alertas luego de dos fallas consecutivas; requiere autorizacion.
- `POST /operations/promotions/refresh` fuerza la actualizacion del feed de
  promociones de La Gallega; requiere autorizacion y rechaza trabajos simultaneos.

Fuera del desarrollo local, configura `CONVIENE_ADMIN_KEY` con un valor aleatorio
no versionado de al menos 24 caracteres, sin espacios al inicio o al final, y
envialo en `X-Admin-Key`. Sin una clave valida, estas rutas devuelven `503`;
con clave incorrecta, `403`. `GET /health` sigue siendo publico sin exponer
diagnosticos. `CONVIENE_CORS_ORIGINS` define los origenes Web permitidos
(separados por comas). En desarrollo (`CONVIENE_ENV=development`) se admiten
ademas `localhost` y `127.0.0.1` con puerto. El script Windows activa ese modo;
Docker usa produccion y Compose publica solo en loopback.

Al iniciar, y luego cada seis horas, el backend actualiza ese feed estructurado.
Se puede modificar el intervalo con `CONVIENE_PROMOTIONS_REFRESH_SECONDS`
(minimo 300 segundos). El ultimo catalogo valido se conserva en
`data/runtime/la-gallega-catalog.json` y los eventos se registran en
`data/runtime/scraper-events.jsonl`; ambos archivos se excluyen de Git.
El refresco usa un bloqueo de archivo en `data/runtime` para evitar trabajos
simultaneos entre procesos que comparten ese directorio. Una solicitud manual
concurrente recibe HTTP 409; el refresco programado conserva el ultimo catalogo
valido mientras otro proceso trabaja. En despliegues con varias instancias, el
directorio runtime debe estar en un volumen compartido para mantener esa garantia.

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

En consultas a la API, Python decide la identidad y Flutter solo aplica una
comprobacion defensiva antes de sumar precios. Las reglas Dart de busqueda por
nombre siguen disponibles para el modo local; las pruebas de ambos lados cubren
los mismos riesgos de EAN, tamaño, pack y variantes para detectar divergencias.
La referencia compartida esta en `test/fixtures/product_identity_cases.json`.

## Rendimiento y cache

- Las tiendas se consultan en paralelo.
- Los productos de un changuito se comparan en paralelo.
- Los detalles de La Gallega se descargan con un grupo limitado de workers.
- Las busquedas se almacenan durante 120 segundos y consideran el contexto de sucursal/canal.
- Las caches de productos y equivalencias tienen un maximo de entradas; un
  resultado vacio de busqueda general se reintenta en la siguiente solicitud.
- Los descuentos se almacenan durante 5 minutos por fecha y conjunto de tiendas.
- Las solicitudes simultaneas identicas comparten el mismo trabajo en curso.

La cache vive en memoria y se elimina al reiniciar el proceso.

## Fuentes de descuentos

- Coto: endpoint oficial de promociones multicanal.
- Carrefour: archivo versionado para septiembre de 2026 y entidades oficiales
  para fechas no cubiertas por el archivo.
- La Gallega: feed estructurado vigente, legal de Banco Coinag y catalogo
  versionado como respaldo cuando una fuente no esta disponible.

Los datos versionados viven en `data/`. El backend interpreta dias, fechas
especificas, porcentajes, cuotas, topes, compras minimas y medios compatibles.
Cuando una promocion exige una combinacion, por ejemplo MODO y un banco
determinado, la app requiere que ambos medios esten seleccionados.
El archivo `descuentos-coto.json` conserva la referencia de captura; como no
contiene promociones, Coto continua usando su endpoint oficial.

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
.\backend\scraper_api\.venv\Scripts\python.exe -m pip install -r backend\scraper_api\requirements-dev.txt
.\backend\scraper_api\.venv\Scripts\python.exe `
  -m pytest backend\scraper_api\tests -q
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

`ApiRepository` conserva un directorio local de supermercados y productos para
mantener la interfaz disponible. Si falla la API, las busquedas, cotizaciones y
promociones reales muestran un error: no se sustituyen con precios de muestra.
