<p align="center">
  <img src="assets/brand/conviene_logo.png" width="150" alt="Conviene">
</p>

<h1 align="center">Conviene</h1>

<p align="center">
  Compara precios reales, arma tu changuito y descubre donde conviene comprar.
</p>

<p align="center">
  Flutter · FastAPI · Firebase Auth · Supabase · Coto · Carrefour · La Gallega
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
- El codigo de barras identifica el producto; si falta su EAN en otra tienda,
  se busca por nombre y se verifica marca, cantidad, presentacion, pack y variante.
- Alternativas sugeridas por separado, sin sumarlas como equivalencias confirmadas.
- Changuito con comparacion por supermercado y productos faltantes.
- Plan combinado con el mejor precio de cada producto.
- Descuentos compatibles con las tarjetas, bancos y billeteras del usuario.
- Errores de consulta diferenciados de productos no encontrados, sin precios simulados.
- Resultados parciales visibles con aviso cuando falla alguna tienda.
- Tema claro u oscuro desde Inicio, con preferencia guardada en el dispositivo.
- Cuentas personales y aportes de precios compartidos, identificados por autor y fecha.

## Como funciona

```text
Usuario
  |
  v
Flutter app  --->  FastAPI  --->  Coto / Carrefour / La Gallega
     |
     +--------> Firebase Auth (cuentas y correo)
     +--------> Supabase Postgres (aportes de usuarios)
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

En otra terminal, prepara la configuracion publica de Supabase. El proyecto
`Conviene` ya esta creado; `supabase.local.json` contiene su URL y su clave
publicable y esta excluido de Git. La configuracion publica de Firebase para
Web y Android esta en `lib/firebase_config.dart`. Para un clon nuevo, copia
`supabase.local.example.json` a `supabase.local.json` y completa ambos valores
desde **Supabase > Connect**. Nunca uses una clave `service_role` o `sb_secret_`
en Flutter.

Inicia Flutter Web:

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
$env:CONVIENE_ENV = 'development'
.\.venv\Scripts\python.exe -m uvicorn api:app --host 127.0.0.1 --port 8000 --reload
```

</details>

## Configuracion

Flutter usa `CONVIENE_API_BASE_URL` para localizar el backend y requiere
`SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` para iniciar sesion:

```powershell
flutter run -d chrome `
  --dart-define=CONVIENE_API_BASE_URL=http://127.0.0.1:8000 `
  --dart-define-from-file=supabase.local.json
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

## Uso diario y despliegue

La app consulta precios de los catalogos disponibles y muestra una advertencia
cuando la disponibilidad no esta confirmada. Los importes pueden variar segun
la ubicacion, el canal de venta y el momento de la compra.

Para desplegar el backend con Docker:

```powershell
docker compose up --build -d
```

La API queda en el puerto `8000`. Para una publicacion real, sirve Flutter Web
detras de HTTPS y define la URL publica de la API durante el build:

```powershell
flutter build web --release -O1 --no-web-resources-cdn `
  --dart-define=CONVIENE_API_BASE_URL=https://api.tu-dominio.com `
  --dart-define-from-file=supabase.local.json
```

El nivel `-O1` evita un fallo de arranque observado con la optimizacion web
predeterminada en la version de FlutterFire fijada por este proyecto. Verifica
el build servido por HTTP antes de publicarlo; no basta con que compile.

Docker Compose publica la API solo en `127.0.0.1:8000`. Para acceso publico,
usalo detras de un proxy HTTPS y configura `.env` a partir de `.env.example`:

| Variable | Uso |
| --- | --- |
| `CONVIENE_CORS_ORIGINS` | Origenes de Flutter Web, separados por comas. |
| `CONVIENE_ADMIN_KEY` | Clave aleatoria de al menos 24 caracteres para diagnosticos y refresco manual. |
| `CONVIENE_IMAGE_ALLOWED_HOSTS` | CDN adicionales, separados por comas. |

En produccion, las operaciones administrativas quedan cerradas si falta la
clave o es demasiado corta. Se envia en `X-Admin-Key`. CORS no sustituye la
autenticacion. El refresco de La Gallega usa un bloqueo compartido por los
procesos que montan el mismo directorio `data/runtime`.

## Comparacion del changuito

Conviene presenta tres perspectivas:

1. **Tu seleccion:** conserva la tienda donde agregaste cada producto.
2. **Un solo supermercado:** prioriza comercios que tengan el changuito completo.
3. **Mejor precio por producto:** combina tiendas para minimizar el total final.

La comparacion consulta primero el codigo de barras (GTIN) y luego nombres
abreviados por marca y contenido. Las consultas por tienda no compiten por un
limite global de resultados. Si ambos catalogos publican codigos distintos,
no se consideran el mismo producto aunque sus nombres se parezcan.

Si hay un candidato de la misma categoria sin identidad confirmada, la API lo
devuelve en `alternatives`. Se muestra como sugerencia, sin sumar su precio al
total ni marcar ese supermercado como proveedor del producto elegido.

Un producto no encontrado en el catalogo consultado no implica que no exista
en otra sucursal. La app distingue esa situacion de falta de stock publicado
y errores de la fuente; no completa comparaciones con precios simulados.
La busqueda devuelve `store_status` por tienda y `partial` cuando alguna fuente
falla; los resultados de las otras tiendas siguen visibles con una advertencia.

## Descuentos

Las promociones se obtienen desde las fuentes publicas de cada comercio y se
normalizan por entidad, porcentaje, tope, dia, vigencia y canal. La app resalta
los beneficios compatibles con los medios de pago activos.

Los registros cuyos legales estan vencidos se omiten, aunque la fuente todavia
los marque como activos. Conviene prefiere no mostrar una promocion antes que
inventar una fecha o un porcentaje.

## Cuentas y aportes

El primer acceso pide nombre de usuario publico, correo y contrasena. Firebase
Authentication gestiona registro, inicio de sesion, verificacion del correo y
recuperacion de contrasena; Supabase solo guarda perfiles publicos y aportes.
La app no guarda contrasenas en la base de datos ni en el repositorio. El
correo debe estar verificado antes de entrar o publicar precios. Firebase
envia los correos con sus plantillas predeterminadas, sin requerir un dominio
propio. Consulta las [cuotas de envio](https://firebase.google.com/docs/auth/limits)
antes de ampliar el servicio.

Al final de los resultados, **Ayuda a agregar productos** permite publicar
un precio que falta en Coto, Carrefour o La Gallega. El formulario incluye
producto, marca, presentacion, codigo de barras opcional, precio, disponibilidad
y enlaces de imagen/fuente. El aporte aparece en futuras busquedas de otros
usuarios, con su autor y fecha; solo su autor puede editarlo. Estos precios
son aportes comunitarios, no cotizaciones verificadas por el supermercado.

Las migraciones en `supabase/migrations/` crean los perfiles, los precios y las
politicas de seguridad a nivel de fila (RLS). Para otra instancia, aplica las
migraciones en orden y conecta su proyecto Firebase en **Supabase >
Authentication > Third-Party Auth**. Las politicas exigen el ID de proyecto,
emisor y correo verificado; la clave publicable por si sola no permite leer
los aportes. Actualiza esos identificadores en la migracion si usas otro
proyecto. Configura los dominios autorizados de Firebase Auth para tu dominio
publico y sirve la app y la API por HTTPS. Las cuentas creadas antes con
Supabase Auth no se migran automaticamente a Firebase Auth; sus datos de base
permanecen intactos. No publiques contrasenas de base ni claves secretas.

## API

| Metodo | Ruta | Uso |
| --- | --- | --- |
| `GET` | `/health` | Estado del servicio. |
| `GET` | `/search` | Busqueda normalizada de productos. |
| `POST` | `/compare` | Comparacion de productos y cantidades. |
| `POST` | `/products/equivalents` | Mismo producto por tienda, con estado de consulta. |
| `GET` | `/discounts` | Promociones por fecha y supermercado. |
| `GET` | `/image` | Proxy de imagenes para Flutter Web. |
| `GET` | `/operations` | Diagnosticos administrativos. |
| `POST` | `/operations/promotions/refresh` | Refresco manual de promociones. |

El contrato completo, ejemplos y detalles del scraper estan en
[backend/scraper_api/README.md](backend/scraper_api/README.md).

## Desarrollo

```powershell
flutter analyze
flutter test
flutter build web
```

```powershell
.\backend\scraper_api\.venv\Scripts\python.exe -m pip install -r backend\scraper_api\requirements-dev.txt
.\backend\scraper_api\.venv\Scripts\python.exe `
  -m pytest backend\scraper_api\tests -q
```

Los casos de identidad compartidos por Python y Dart viven en
`test/fixtures/product_identity_cases.json`.

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
- Sin el backend, la interfaz conserva datos locales, pero las busquedas,
  cotizaciones y promociones reales muestran error en vez de precios de muestra.
- Sin Supabase configurado no se puede iniciar sesion ni ver los aportes.

Fuentes: [Coto](https://www.coto.com.ar/),
[Carrefour Argentina](https://www.carrefour.com.ar/) y
[La Gallega](https://www.lagallega.com.ar/).
