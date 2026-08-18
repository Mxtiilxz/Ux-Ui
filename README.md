# Kairos

Red social para estudiantes de liceos técnico-profesionales. Conecta alumnos con empresas,
prácticas profesionales y la comunidad de su especialidad.

## Entornos publicados

| Entorno | URL | Descripción |
|---|---|---|
| Producción | [kairoswebapp.netlify.app](https://kairoswebapp.netlify.app) | Aplicación real: cuentas, PostgreSQL en Supabase y archivos en Supabase Storage |
| API | [ux-ui-b1s1.onrender.com](https://ux-ui-b1s1.onrender.com/health) | Backend en Render. `GET /health` responde `{"status":"ok"}` |
| Demo | [kairos-legacydemo.netlify.app](https://kairos-legacydemo.netlify.app) | Build con `DEMO_MODE=true`, sin backend. Ver [DEMO.md](DEMO.md) |

Ambos servicios usan planes gratuitos que se suspenden por inactividad. Render apaga la API
tras 15 minutos y tarda unos 50 segundos en volver; la aplicación se adelanta consultando
`/health` al cargar la página. Supabase pausa el proyecto tras 7 días y requiere
reactivación manual desde su panel.

## Documentación

| Archivo | Contenido |
|---|---|
| [PRODUCCION.md](PRODUCCION.md) | Despliegue, cuentas de acceso, publicación y pendientes |
| [DEMO.md](DEMO.md) | Modo demo sin backend y eventos de Google Analytics |
| [backend/README.md](backend/README.md) | Arquitectura, modelo de datos, endpoints y rate limiting |
| [frontend/README.md](frontend/README.md) | Estructura Flutter, tema y flags de compilación |
| [docs/accessibility/](docs/accessibility/) | Auditoría WCAG 2.2 AA y reporte de remediación |
| [\_\_tests\_\_/README.md](__tests__/README.md) | Tests de integración (pytest) |

## Stack

| Capa | Tecnología |
|---|---|
| Frontend | Flutter 3, Material 3 |
| Backend | ASP.NET Core 8, Clean Architecture (CQRS + MediatR) |
| Base de datos | PostgreSQL vía Npgsql EF Core (Supabase) |
| Almacenamiento | Supabase Storage en producción, filesystem local en desarrollo |
| Tiempo real | ASP.NET Core SignalR |
| Generación de PDF | QuestPDF |
| Autenticación | JWT Bearer HS256 |
| Analítica | Google Analytics 4 |
| Despliegue | Render (Docker) y Netlify |

## Estructura

```
backend/
  Dockerfile
  Kairos.sln
  src/
    Kairos.Domain/          Entidades y enums
    Kairos.Application/     Casos de uso (CQRS, FluentValidation)
    Kairos.Infrastructure/  EF Core, Storage, JWT, PDF, seeders
    Kairos.API/             Controllers, SignalR, middleware
  tests/
    Kairos.Application.Tests/   Traducción a SQL de las consultas
frontend/
  lib/
    core/                   API, servicios, tema, validación, utilidades
    features/               auth, home, jobs, network, chat, profile, staff
  test/                     Accesibilidad, contraste, política de contraseñas
```

## Ejecución local

Requiere [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8), PostgreSQL 14 o
superior y [Flutter 3](https://docs.flutter.dev/get-started/install) con soporte web.

### Base de datos

```sql
CREATE DATABASE kairos;
CREATE USER kairos_user WITH PASSWORD 'kairos2026';
GRANT ALL PRIVILEGES ON DATABASE kairos TO kairos_user;
```

Ajustar la cadena de conexión en `backend/src/Kairos.API/appsettings.Development.json`.

### Backend

```bash
cd backend
dotnet restore
dotnet run --project src/Kairos.API
```

Queda en `http://localhost:5001`, con Swagger en `/swagger`. Las migraciones se aplican
solas al arrancar.

En `Development` el seeder crea usuarios de prueba, todos con la contraseña `Kairos2026!`:
siete estudiantes con competencias variadas para poblar Quick Match, dos cuentas de staff
y dos empresas. Los correos están en `DevDataSeeder.cs`. Ese mismo entorno usa el
filesystem local para las imágenes, así que no hace falta una cuenta de Supabase para
desarrollar.

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d web-server --web-port=3000 --dart-define=API_URL=http://localhost:5001/api
```

Sin el `--dart-define` la aplicación apunta a `localhost:5001` de todos modos, pero
conviene ser explícito. Abrir `http://localhost:3000`.

### Comprobaciones

```bash
cd backend && dotnet build && dotnet test
cd frontend && flutter analyze && flutter test
```

## Variables de entorno del backend

Los secretos no van en `appsettings.json`, que está versionado. El doble guion bajo es la
convención de .NET para anidar secciones de configuración.

| Variable | Descripción |
|---|---|
| `ConnectionStrings__DefaultConnection` | Cadena de conexión de PostgreSQL |
| `Jwt__SecretKey` | Clave de firma, mínimo 32 caracteres |
| `Supabase__Url` | URL del proyecto |
| `Supabase__ServiceKey` | Clave `service_role`, solo en el servidor |
| `Supabase__Bucket` | Nombre del bucket, por ejemplo `kairos-media` |
| `ASPNETCORE_ENVIRONMENT` | `Production` |

Para sembrar una instalación nueva existen además `SEED_STAFF_*` y `SEED_DEMO_*`, que
deben retirarse tras el primer arranque. Ver [PRODUCCION.md](PRODUCCION.md).

## Despliegue

La base de datos y los archivos van en Supabase; la API necesita su propio host porque
Supabase no ejecuta contenedores .NET. `backend/Dockerfile` expone el puerto 8080 y está
preparado para Render, con `backend` como Root Directory. El frontend se compila y se
publica en Netlify:

```bash
cd frontend
flutter build web --release --dart-define=BACKEND_URL=https://TU-BACKEND
netlify deploy --prod --dir=build/web
```

Un solo indicador basta: `core/config.dart` deriva de él la URL de la API y las de ambos
hubs SignalR. El procedimiento completo, con las variables y los detalles de
configuración de cada servicio, está en [PRODUCCION.md](PRODUCCION.md).

## Funcionalidades

- Registro e inicio de sesión con JWT para tres roles: estudiante, empresa y staff. Las
  cuentas de alumno nacen pendientes y las habilita el liceo; el rol staff no se puede
  solicitar desde el formulario público y esas cuentas se crean desde el panel.
- Feed con publicaciones, me gusta y comentarios, con avisos en tiempo real al autor.
- Subida de imágenes con texto alternativo escrito por el autor. Si lo deja vacío, la
  imagen se publica como decorativa.
- Ofertas laborales: creación, edición, postulación y revisión de postulantes.
- Quick Match: los estudiantes declaran sus competencias y activan su visibilidad; las
  empresas buscan por competencia, ven el porcentaje de coincidencia y contactan por chat
  con una plantilla de mensaje personalizable.
- Conexiones bilaterales con solicitud y respuesta.
- Preferencias de privacidad por usuario: quién puede escribirle y quién ve lo que publica.
- Perfil editable con formación y experiencia, que alimentan el CV descargable en PDF.
- Mensajería en tiempo real.
- Panel de administración: aprobación de cuentas, gestión de usuarios, catálogo de
  competencias, historial de altas e importación de alumnos por CSV.
- Interfaz auditada contra WCAG 2.2 nivel AA.
- Rate limiting en login, generación de CV y búsqueda de Quick Match.
- Modo demo sin backend para estudios de usabilidad.

## Limitaciones conocidas

El reporte mensual del panel de staff refleja solo una parte de la actividad: la tabla
`user_activities` únicamente se alimenta al crear publicaciones. No afecta al CV, que se
construye desde el perfil.

Supabase pausa los proyectos gratuitos tras 7 días de inactividad y hay que reactivarlos
manualmente.

El repositorio debe permanecer privado: el historial de git contiene secretos anteriores a
la migración, ya rotados en el servicio pero no eliminados del historial.

Ambas están detalladas en [PRODUCCION.md](PRODUCCION.md).

## Arquitectura

```
Flutter Web  ──HTTPS──►  ASP.NET Core 8  ──►  PostgreSQL (Supabase)
 (Netlify)                 (Render)       │
     │                         │          └──►  Supabase Storage
     └────WebSocket────►  SignalR Hub  ──►  clientes conectados
```
