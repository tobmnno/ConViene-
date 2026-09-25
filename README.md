<p align="center">
  <img src="assets/brand/conviene_logo.png" width="150" alt="Conviene">
</p>

<h1 align="center">Conviene</h1>

<p align="center">
  Compara precios reales, arma tu changuito y descubre donde conviene comprar.
</p>

<p align="center">
  Flutter · FastAPI · Coto · Carrefour · La Gallega
</p>

Conviene unifica precios y promociones publicas de supermercados argentinos en
una experiencia movil simple. Compara el mismo producto entre comercios,
considera tus medios de pago y calcula tanto la mejor compra completa como la
combinacion mas barata entre distintas tiendas.

> Los precios, el stock y las promociones pertenecen a cada supermercado y
> pueden variar por sucursal, ubicacion, canal o momento de la consulta.

## Que ofrece

- Busqueda simultanea en Coto, Carrefour y La Gallega.
- Precios, disponibilidad e imagenes obtenidos de fuentes publicas.
- Matching por marca, cantidad, presentacion, pack, sabor y variante.
- Changuito con comparacion por supermercado y productos faltantes.
- Plan combinado con el mejor precio de cada producto.
- Descuentos compatibles con las tarjetas, bancos y billeteras del usuario.
- Fallback local para que la interfaz siga disponible si la API falla.

## Como funciona

```text
Usuario
  |
  v
Flutter app  --->  FastAPI  --->  Coto / Carrefour / La Gallega
  ^                  |
  |                  v
  +---- precios, imagenes, promociones y productos normalizados
```

El backend consulta las tiendas en paralelo, normaliza los resultados y aplica
un ranking de relevancia. Para comparar productos valida identidad, tamaño,
unidad, formato pack y variantes; una presentacion incompatible no se usa para
calcular el total.

## Inicio rapido

### Requisitos

- Flutter con Dart 3.11 o superior.
- Python 3.12 o 3.13 recomendado.
- Conexion a Internet.

### Windows

```powershell
git clone https://github.com/tobmnno/ConViene-.git
cd ConViene-
flutter pub get
.\backend\scraper_api\INSTALAR_WINDOWS.bat
```

Inicia el backend:

```powershell
.\backend\scraper_api\INICIAR_BACKEND.bat
```

En otra terminal, inicia Flutter Web:

```powershell
.\INICIAR_APP_WEB.bat
```

La app queda disponible en `http://127.0.0.1:53246` y la API en
`http://127.0.0.1:8000`. La documentacion interactiva de la API esta en
[http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs).

<details>
<summary>Instalacion manual del backend</summary>

```powershell
cd backend\scraper_api
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m camoufox fetch
.\.venv\Scripts\python.exe -m uvicorn api:app --host 127.0.0.1 --port 8000 --reload
```

</details>

## Configuracion

Flutter usa `CONVIENE_API_BASE_URL` para localizar el backend:

```powershell
flutter run -d chrome `
  --dart-define=CONVIENE_API_BASE_URL=http://127.0.0.1:8000
```

| Entorno | URL del backend |
| --- | --- |
| Navegador local | `http://127.0.0.1:8000` |
| Emulador Android | `http://10.0.2.2:8000` |
| Telefono fisico | `http://<IP_DE_LA_PC>:8000` |
| Produccion | URL HTTPS publica |

Para usar un telefono fisico, ambos dispositivos deben estar en la misma red y
la API debe iniciarse con `--host 0.0.0.0`. No expongas el servidor de desarrollo
directamente a Internet.

## Comparacion del changuito

Conviene presenta tres perspectivas:

1. **Tu seleccion:** conserva la tienda donde agregaste cada producto.
2. **Un solo supermercado:** prioriza comercios que tengan el changuito completo.
3. **Mejor precio por producto:** combina tiendas para minimizar el total final.

Si un supermercado no tiene un producto comparable, se muestra como faltante;
nunca se reemplaza por un precio cero.

## Descuentos

Las promociones se obtienen desde las fuentes publicas de cada comercio y se
normalizan por entidad, porcentaje, tope, dia, vigencia y canal. La app resalta
los beneficios compatibles con los medios de pago activos.

Los registros cuyos legales estan vencidos se omiten, aunque la fuente todavia
los marque como activos. Conviene prefiere no mostrar una promocion antes que
inventar una fecha o un porcentaje.

## API

| Metodo | Ruta | Uso |
| --- | --- | --- |
| `GET` | `/health` | Estado del servicio. |
| `GET` | `/search` | Busqueda normalizada de productos. |
| `POST` | `/compare` | Comparacion de productos y cantidades. |
| `GET` | `/discounts` | Promociones por fecha y supermercado. |
| `GET` | `/image` | Proxy de imagenes para Flutter Web. |

El contrato completo, ejemplos y detalles del scraper estan en
[backend/scraper_api/README.md](backend/scraper_api/README.md).

## Desarrollo

```powershell
flutter analyze
flutter test
flutter build web
```

```powershell
.\backend\scraper_api\.venv\Scripts\python.exe `
  -m unittest discover -s backend\scraper_api\tests -q
```

## Estructura

```text
lib/                         App Flutter
backend/scraper_api/         FastAPI, scrapers y matching
assets/                      Marca y logos de medios de pago
test/                        Pruebas de Flutter
backend/scraper_api/tests/   Pruebas del backend
```

## Consideraciones

- Los precios pueden variar por sucursal, codigo postal, stock o canal.
- La primera busqueda puede tardar; las siguientes aprovechan una cache corta.
- Los sitios externos pueden modificar sus endpoints o estructura sin aviso.
- El matching reduce errores, pero no reemplaza un catalogo maestro basado en EAN.
- Sin el backend, la app usa datos locales pensados para desarrollo visual.

Fuentes: [Coto](https://www.coto.com.ar/),
[Carrefour Argentina](https://www.carrefour.com.ar/) y
[La Gallega](https://www.lagallega.com.ar/).
