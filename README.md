# Conviene

Conviene es una aplicacion Flutter para comparar precios de supermercados
argentinos, armar un changuito y evaluar donde conviene comprar teniendo en
cuenta precios, disponibilidad y promociones asociadas a los medios de pago del
usuario.

El proyecto integra informacion publica de:

- [Coto](https://www.coto.com.ar/)
- [Carrefour Argentina](https://www.carrefour.com.ar/)
- [La Gallega](https://www.lagallega.com.ar/)

> Conviene es un comparador independiente. Los precios, el stock y las
> promociones pertenecen a cada supermercado y pueden variar por sucursal,
> ubicacion, canal de venta o momento de la consulta.

## Funcionalidades

- Busqueda simultanea de productos en los supermercados seleccionados.
- Precios e imagenes obtenidos desde las fuentes publicas de cada comercio.
- Ordenamiento por mejor precio, precio unitario o nombre.
- Changuito vacio por defecto: solo contiene productos agregados por el usuario.
- Conservacion del supermercado donde se eligio cada producto.
- Comparacion del changuito completo en un unico supermercado.
- Alternativa de compra combinada con el producto mas barato de cada comercio.
- Deteccion de productos faltantes para evitar totales engañosos en cero.
- Matching por marca, nombre, presentacion, cantidad, pack, sabor y variante.
- Rechazo de comparaciones incompatibles, por ejemplo 200 cc contra 350 cc.
- Promociones bancarias filtradas por fecha, supermercado y tipo de medio de pago.
- Seleccion de tarjetas, bancos y billeteras virtuales con sus logos oficiales.
- Resaltado de promociones compatibles con los medios de pago activos.
- Fallback local para mantener operativa la interfaz si la API no responde.

## Arquitectura

```text
Conviene
|-- lib/                         Aplicacion Flutter
|   |-- models/                  Entidades de productos, precios y promociones
|   |-- repositories/            Acceso a la API y fallback local
|   |-- services/                Busqueda, descuentos y comparacion
|   |-- state/                   Estado global de la aplicacion
|   |-- screens/                 Pantallas y flujos principales
|   `-- widgets/                 Componentes reutilizables
|-- backend/scraper_api/         API FastAPI y scrapers
|   |-- scrapers/                Integraciones por supermercado
|   |-- services/                Ranking, matching, descuentos y cache
|   `-- tests/                   Pruebas del contrato del backend
|-- assets/                      Logo, tipografia e imagenes de medios de pago
|-- test/                        Pruebas de la aplicacion Flutter
|-- web/                         Configuracion de Flutter Web
`-- android/                     Configuracion de Android
```

La aplicacion usa por defecto `http://127.0.0.1:8000` como API. El backend
consulta los supermercados en paralelo, normaliza los resultados y devuelve un
contrato comun. Flutter transforma ese contrato en productos, precios y
promociones consumibles por la interfaz.

```text
Usuario -> Flutter -> FastAPI -> Coto / Carrefour / La Gallega
                    <- datos normalizados, imagenes y descuentos
```

## Requisitos

### Aplicacion

- [Flutter](https://docs.flutter.dev/get-started/install) compatible con Dart 3.11 o superior.
- Chrome, Edge, Android Studio o un dispositivo Android para ejecutar la app.

Verificar la instalacion:

```powershell
flutter doctor
flutter --version
```

### Backend

- Python 3.12 o 3.13 recomendado.
- Conexion a Internet.
- PowerShell en Windows para seguir los ejemplos de esta guia.

Python 3.14 puede funcionar, pero 3.12 y 3.13 ofrecen mayor compatibilidad con
las dependencias actuales del navegador automatizado.

## Inicio rapido en Windows

### 1. Clonar el repositorio

```powershell
git clone https://github.com/tobmnno/ConViene-.git
cd ConViene-
```

### 2. Instalar Flutter

```powershell
flutter pub get
```

### 3. Instalar el backend

La forma mas simple es ejecutar:

```powershell
.\backend\scraper_api\INSTALAR_WINDOWS.bat
```

El script crea `backend/scraper_api/.venv`, instala las dependencias y descarga
Camoufox. La instalacion manual equivalente es:

```powershell
cd backend\scraper_api
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m camoufox fetch
cd ..\..
```

### 4. Levantar la API

En una terminal:

```powershell
.\backend\scraper_api\INICIAR_BACKEND.bat
```

Tambien puede iniciarse manualmente:

```powershell
cd backend\scraper_api
.\.venv\Scripts\python.exe -m uvicorn api:app --host 127.0.0.1 --port 8000 --reload
```

Comprobar que funciona:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

La documentacion interactiva queda disponible en
[http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs).

### 5. Levantar Flutter Web

Abrir otra terminal en la raiz del repositorio y ejecutar:

```powershell
.\INICIAR_APP_WEB.bat
```

El script publica la aplicacion en `http://127.0.0.1:53246`. Tambien se puede
usar Flutter directamente:

```powershell
flutter run -d chrome --dart-define=CONVIENE_API_BASE_URL=http://127.0.0.1:8000
```

La terminal del backend debe permanecer abierta mientras se usa la aplicacion.

## Configuracion de la API

La URL se define en compilacion mediante `CONVIENE_API_BASE_URL`:

```powershell
flutter run -d chrome `
  --dart-define=CONVIENE_API_BASE_URL=http://127.0.0.1:8000
```

### Emulador Android

En el emulador estandar de Android, `127.0.0.1` apunta al propio emulador. Para
acceder al backend de la computadora se utiliza `10.0.2.2`:

```powershell
flutter run -d emulator-5554 `
  --dart-define=CONVIENE_API_BASE_URL=http://10.0.2.2:8000
```

### Telefono fisico

El telefono y la computadora deben estar en la misma red local. La API debe
escuchar en todas las interfaces y Flutter debe usar la IP local de la PC:

```powershell
cd backend\scraper_api
.\.venv\Scripts\python.exe -m uvicorn api:app --host 0.0.0.0 --port 8000
```

```powershell
flutter run -d <ID_DEL_DISPOSITIVO> `
  --dart-define=CONVIENE_API_BASE_URL=http://<IP_DE_LA_PC>:8000
```

No se recomienda exponer este servidor de desarrollo directamente a Internet.

## Como funciona la busqueda

1. Flutter envia la consulta y los supermercados activos a `GET /search`.
2. El backend consulta primero los endpoints directos disponibles de cada tienda.
3. Si una fuente no ofrece resultados directos, se utiliza el navegador
   automatizado como respaldo.
4. Los resultados se normalizan y se puntuan por relevancia.
5. La app muestra nombre, supermercado, precio, precio unitario e imagen.

Las consultas a distintos supermercados se ejecutan en paralelo. Los resultados
se guardan en una cache corta para acelerar busquedas repetidas sin mantener
precios viejos durante demasiado tiempo.

## Matching y comparacion del changuito

Los nombres publicados por cada supermercado no son identicos. Para decidir si
dos resultados representan el mismo producto se consideran:

- Marca y palabras de identidad del producto.
- Tipo de producto.
- Unidad y cantidad normalizada en gramos o mililitros.
- Cantidad de unidades en un pack.
- Variantes como entera, descremada, light, zero o sin lactosa.
- Sabores como vainilla, chocolate o frutilla.
- EAN cuando ambas fuentes lo proporcionan.

Una diferencia de presentacion relevante invalida la equivalencia. Si una tienda
no tiene un producto comparable, aparece como faltante y no se suma un precio
cero.

El changuito ofrece tres lecturas:

- **Seleccion original:** mantiene la tienda elegida al agregar cada producto.
- **Un solo supermercado:** calcula el total por comercio y prioriza opciones
  que tengan todos los productos.
- **Mejor precio por producto:** permite combinar tiendas para obtener el menor
  total posible.

## Descuentos y medios de pago

El backend consulta las fuentes publicas de descuentos de cada supermercado:

- Coto: endpoint oficial utilizado por su pagina de descuentos.
- Carrefour: datos oficiales de promociones y sus legales.
- La Gallega: beneficios publicados por dia y entidad.

Las promociones se normalizan con porcentaje, tope, dias, vigencia, canal,
entidad y condiciones. La aplicacion cruza esos datos con los medios de pago que
el usuario activo y marca en verde los beneficios compatibles.

Una promocion no se considera vigente si sus legales indican una fecha vencida,
aunque el sitio todavia la marque como activa. Cuando una fuente publica datos
incompletos o contradictorios, la API devuelve una advertencia y evita inventar
fechas o porcentajes.

## API del backend

| Metodo | Ruta | Descripcion |
| --- | --- | --- |
| `GET` | `/` | Informacion basica del servicio. |
| `GET` | `/health` | Estado de la API y supermercados disponibles. |
| `GET` | `/stores` | IDs internos y IDs utilizados por Flutter. |
| `GET` | `/search` | Busca y ordena productos reales. |
| `POST` | `/search` | Variante de busqueda con cuerpo JSON. |
| `POST` | `/compare` | Compara una lista de productos y cantidades. |
| `GET` | `/discounts` | Obtiene promociones para una fecha y tiendas. |
| `GET` | `/image` | Proxy con cache para imagenes de productos. |
| `GET` | `/docs` | Documentacion OpenAPI interactiva. |

Ejemplos:

```powershell
Invoke-RestMethod `
  "http://127.0.0.1:8000/search?q=leche%20entera%201l&limit=10&stores=coto&stores=carrefour"
```

```powershell
Invoke-RestMethod `
  "http://127.0.0.1:8000/discounts?date=2026-09-25&stores=coto&stores=la_gallega"
```

Los IDs aceptados son `coto`, `carrefour`, `la_gallega`, `lagallega` y
`la-gallega`. Internamente, las variantes de La Gallega se normalizan como
`la_gallega`.

## Fallback y funcionamiento sin backend

`ApiRepository` tiene un repositorio local de respaldo. Si la API no esta
disponible, una solicitud supera el tiempo limite o la respuesta no cumple el
contrato esperado, Flutter utiliza datos mock para evitar que la interfaz quede
inutilizable.

El fallback sirve para desarrollo visual y pruebas. Para mostrar precios,
imagenes y promociones actuales debe estar ejecutandose el backend.

## Pruebas y calidad

Desde la raiz del repositorio:

```powershell
flutter analyze
flutter test
flutter build web
```

Pruebas del backend:

```powershell
.\backend\scraper_api\.venv\Scripts\python.exe `
  -m unittest discover -s backend\scraper_api\tests -q
```

Las pruebas cubren el contrato de la API, normalizacion de precios, alias de
supermercados, descuentos, seleccion de medios de pago, matching por tamaño y
pack, y las distintas estrategias de comparacion del changuito.

Las pruebas marcadas como `live` dependen de los sitios externos y pueden
omitirse en una ejecucion normal para evitar falsos errores por cambios o caidas
temporales de terceros.

## Builds

### Web

```powershell
flutter build web `
  --dart-define=CONVIENE_API_BASE_URL=https://api.ejemplo.com
```

La salida queda en `build/web`.

### Android

```powershell
flutter build apk --release `
  --dart-define=CONVIENE_API_BASE_URL=https://api.ejemplo.com
```

Para una distribucion real, el backend debe estar desplegado en una URL HTTPS
accesible desde el dispositivo. `127.0.0.1` solo es apropiado para desarrollo
local.

## Solucion de problemas

### La app muestra datos de ejemplo

Verificar que `http://127.0.0.1:8000/health` responda y que Flutter haya sido
iniciado con la URL correcta en `CONVIENE_API_BASE_URL`.

### La busqueda tarda demasiado

La primera consulta puede demorar porque depende de tres sitios externos. Las
consultas repetidas son mas rapidas por cache. Revisar la terminal del backend
para identificar que supermercado no respondio.

### No aparecen promociones de un supermercado

La fuente puede no publicar promociones para la fecha seleccionada o conservar
legales vencidos. Conviene omite beneficios vencidos para no presentar
informacion incorrecta.

### No aparecen imagenes

Comprobar que el backend este activo. Flutter Web carga las imagenes mediante
`GET /image` para evitar bloqueos CORS y hotlinking de las tiendas.

### Camoufox o Playwright no inicia

Repetir la descarga del navegador:

```powershell
cd backend\scraper_api
.\.venv\Scripts\python.exe -m camoufox fetch
```

## Documentacion adicional

La instalacion y el contrato tecnico del scraper se detallan en
[backend/scraper_api/README.md](backend/scraper_api/README.md).
