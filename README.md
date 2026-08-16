# Kairos

Red social para estudiantes técnico-profesionales de liceos técnicos. Conecta alumnos con empresas, prácticas profesionales y la comunidad de su área.

## Entornos publicados

| Entorno | URL | Qué es |
|---|---|---|
| **Producción** | [kairoswebapp.netlify.app](https://kairoswebapp.netlify.app) | La aplicación real: cuentas, base de datos PostgreSQL en Supabase y archivos en Supabase Storage |
| API | [ux-ui-b1s1.onrender.com](https://ux-ui-b1s1.onrender.com/health) | Backend en Render. `GET /health` responde `{"status":"ok"}` |
| Demo | [kairos-legacydemo.netlify.app](https://kairos-legacydemo.netlify.app) | Build con `DEMO_MODE=true`: sin backend, datos en memoria que se borran al recargar. Para estudios de usabilidad — ver [DEMO.md](DEMO.md) |

> ⏱️ Ambos servicios usan planes gratuitos que se duermen. Render apaga la API tras 15
> minutos sin tráfico y la primera petición tarda unos 50 segundos en despertarla. Supabase
> pausa el proyecto tras 7 días de inactividad y hay que reactivarlo a mano desde su panel.

---

## Documentación

| Archivo | Contenido |
|---|---|
| [PRODUCCION.md](PRODUCCION.md) | Integración con Supabase paso a paso, despliegue, secretos y brechas pendientes |
| [docs/accessibility/](docs/accessibility/) | Auditoría WCAG 2.2 AA y reporte de remediación |
| [DEMO.md](DEMO.md) | Modo demo sin backend y eventos de Google Analytics |
| [backend/README.md](backend/README.md) | Arquitectura, endpoints, rate limiting, cómo levantar la API |
| [frontend/README.md](frontend/README.md) | Estructura Flutter, tema, flags de compilación |
| [\_\_tests\_\_/README.md](__tests__/README.md) | Suite de tests de integración (pytest) |

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Frontend | Flutter 3 (web + mobile) |
| Backend | ASP.NET Core 8 — Clean Architecture (CQRS + MediatR) |
| Base de datos | PostgreSQL via Npgsql EF Core (Supabase) |
| Almacenamiento | Supabase Storage (producción) / filesystem local (dev) |
| Tiempo real | ASP.NET Core SignalR |
| Generación PDF | QuestPDF |
| Autenticación | JWT Bearer HS256 |
| Rate limiting | ASP.NET Core Rate Limiter |
| Analítica | Google Analytics 4 (gtag.js) |
| Deploy backend | Render (contenedor Docker) |
| Deploy frontend | Netlify |

---

## Estructura del repositorio

```
/
├── backend/
│   ├── Dockerfile
│   ├── Kairos.sln
│   └── src/
│       ├── Kairos.Domain/          # Entidades y enums de dominio
│       ├── Kairos.Application/     # Casos de uso (CQRS, FluentValidation)
│       ├── Kairos.Infrastructure/  # EF Core, Storage, JWT, PDF, Seeder
│       └── Kairos.API/             # Controllers, SignalR Hub, Middleware
└── frontend/
    └── lib/
        ├── core/
        │   ├── analytics/          # Eventos de Google Analytics
        │   ├── api/                # ApiClient (Dio + JWT) y backend demo en memoria
        │   ├── config.dart         # Flag kDemoMode
        │   ├── data/               # Datos de relleno de la UI
        │   ├── models/             # UserProfile, etc.
        │   ├── services/           # ChatHubService, SocialHubService (SignalR)
        │   ├── state/              # UserRoleController
        │   ├── theme/              # AppColors, KairosPalette
        │   ├── utils/              # Descarga de archivos (web / stub)
        │   └── widgets/            # AppShell, KCard, PostCard
        └── features/
            ├── auth/               # Login y registro
            ├── home/               # Feed principal
            ├── profile/            # Perfil de usuario con edición y CV PDF
            ├── jobs/               # Ofertas laborales y Quick Match (empresa y estudiante)
            ├── network/            # Red de contactos
            ├── chat/               # Mensajería
            └── staff/              # Panel de administración (aprobación, usuarios, CSV)
```

---

## Requisitos previos

### Backend
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8)
- PostgreSQL 14+ corriendo localmente

### Frontend
- [Flutter 3.x](https://docs.flutter.dev/get-started/install) con soporte web habilitado

---

## Instrucciones para ejecutar el proyecto localmente

### 1. Base de datos

Crear la base de datos y el usuario en PostgreSQL:

```sql
CREATE DATABASE kairos;
CREATE USER kairos_user WITH PASSWORD 'kairos2026';
GRANT ALL PRIVILEGES ON DATABASE kairos TO kairos_user;
```

Ajustar la cadena de conexión en `backend/src/Kairos.API/appsettings.Development.json`.

### 2. Backend

```bash
cd backend

# Restaurar dependencias
dotnet restore

# Aplicar migraciones (crea las tablas). También se aplican automáticamente
# al arrancar la API (ver Program.cs), este paso es solo para adelantarlas.
dotnet ef database update --startup-project src/Kairos.API --project src/Kairos.Infrastructure

# Ejecutar en modo desarrollo (datos de prueba se insertan automáticamente)
dotnet run --project src/Kairos.API
```

El backend quedará disponible en `http://localhost:5001` (puerto fijado en
`appsettings.Development.json`, no 5000).
Swagger UI: `http://localhost:5001/swagger`

> En modo desarrollo, el seeder crea automáticamente usuarios de prueba
> (todos con contraseña `Kairos2026!`):
> - Estudiantes visibles en Quick Match (con competencias cargadas, listos
>   para aparecer en las búsquedas de las empresas):
>   `kairos_user1@kairos.cl` (Ana González Rojas), `benjamin@kairos.cl`,
>   `catalina@kairos.cl`, `diego@kairos.cl`, `fernanda@kairos.cl`,
>   `ignacio@kairos.cl`, `valentina@kairos.cl` — 7 candidatos con
>   distintas competencias para poblar la demo de Quick Match.
> - Staff: `staff1@kairos.cl` / `staff2@kairos.cl`
> - Empresa: `empresa@kairos.cl` (Automatización Industrial S.A. — usa el
>   mensaje de contacto **por defecto**) / `empresa2@kairos.cl`
>   (TechSolutions Chile SpA — arranca con un mensaje de contacto
>   **personalizado**, para ver ambos estados de la funcionalidad)

> En modo `Development` la subida de archivos usa el filesystem local
> automáticamente (`LocalStorageService`) — **no necesitas una cuenta de Supabase
> para desarrollar localmente**, esos valores solo importan en producción.

### 3. Frontend

```bash
cd frontend

# Obtener dependencias
flutter pub get

# Ejecutar en web apuntando al backend LOCAL (el --dart-define es obligatorio;
# sin él, la app apunta por defecto al backend de producción en Railway)
flutter run -d web-server --web-port=3000 --dart-define=API_URL=http://localhost:5001/api
```

Abrir `http://localhost:3000` en el navegador.

---

## Variables de entorno del backend (producción)

> 🔒 **No pongas estos valores en `appsettings.json`.** Ese archivo está versionado en
> git; los secretos deben ir como variables de entorno en el proveedor de hosting.
> Ver Fase 0 de [PRODUCCION.md](PRODUCCION.md).

El doble guion bajo (`__`) es la convención de .NET para anidar secciones:

| Variable | Descripción |
|---|---|
| `ConnectionStrings__DefaultConnection` | Cadena de conexión PostgreSQL (Supabase) |
| `Jwt__SecretKey` | Clave secreta JWT (mínimo 32 caracteres) |
| `Supabase__Url` | URL del proyecto, ej. `https://abcdefgh.supabase.co` |
| `Supabase__ServiceKey` | Clave `service_role` — solo en el servidor |
| `Supabase__Bucket` | Nombre del bucket (ej. `kairos-media`) |
| `ASPNETCORE_ENVIRONMENT` | `Production` |

Solo para el primer arranque, para crear la cuenta de administración:

| Variable | Descripción |
|---|---|
| `SEED_STAFF_EMAIL` | Correo del primer usuario `staff` |
| `SEED_STAFF_PASSWORD` | Su contraseña |
| `SEED_STAFF_NAME` | Su nombre visible (opcional) |

Quitarlas del host después del primer arranque.

---

## Despliegue

### Base de datos y archivos → Supabase

Crear el proyecto, copiar la cadena de conexión y crear un bucket público
`kairos-media`. Pasos detallados en [PRODUCCION.md](PRODUCCION.md).

### Backend → cualquier host con Docker

`backend/Dockerfile` está listo y expone el puerto `8080`. Supabase no ejecuta
contenedores .NET, así que la API necesita su propio host. **Render** es hoy el único
con plan gratuito real y sin tarjeta (Koyeb lo cerró a cuentas nuevas tras la compra
por Mistral; Fly.io lo eliminó). Configurar `backend` como Root Directory, las
variables de entorno listadas arriba más `PORT=8080`, y el health check en
`GET /health`. Detalle completo en [PRODUCCION.md](PRODUCCION.md).

### Frontend → Netlify

```bash
cd frontend
flutter build web --release --dart-define=BACKEND_URL=https://TU-BACKEND
netlify deploy --prod --dir=build/web
```

Un solo indicador basta: `core/config.dart` deriva de él la URL de la API y las de
ambos hubs SignalR. Sin él, la app apunta a `localhost:5001`.

Para generar en cambio la build de demostración sin backend, agregar
`--dart-define=DEMO_MODE=true` (ver [DEMO.md](DEMO.md)).

---

## Funcionalidades implementadas

- Registro e inicio de sesión con JWT (estudiante, staff, empresa)
- Feed social con publicaciones, likes y comentarios en tiempo real (SignalR), con aviso
  en vivo al autor cuando alguien reacciona o lo empieza a seguir
- Subida de imágenes para posts y publicaciones de empleo, con texto alternativo escrito
  por el autor; si lo deja vacío la imagen se publica como decorativa
- Interfaz auditada contra WCAG 2.2 nivel AA (ver [docs/accessibility/](docs/accessibility/))
- Gestión de ofertas laborales: crear, editar, eliminar y ver postulantes
- Postulación a ofertas de empleo
- **Quick Match**: los estudiantes registran sus competencias (técnicas,
  idiomas, experiencia) y activan su visibilidad; las empresas buscan
  candidatos por competencia desde la pestaña Trabajos, ven el % de
  coincidencia y contactan directo por chat con un mensaje automático.
  Cada empresa puede **personalizar su mensaje de contacto** desde la misma
  pestaña Trabajos (tarjeta "Mensaje de contacto"), con los placeholders
  `{nombre}`, `{empresa}` y `{competencias}` que se rellenan al contactar a
  cada candidato. Endpoints: `GET/PUT /api/skills/company/message`.
- Red de contactos (seguir / dejar de seguir usuarios)
- Mensajería en tiempo real
- Perfil de usuario editable con foto de perfil
- Generación de CV en PDF
- Panel de administración de usuarios para staff
- Importación de alumnos vía CSV
- Persistencia de sesión en web (localStorage vía flutter_secure_storage)
- Rate limiting en endpoints sensibles (login, generación de CV, búsqueda de Quick Match)
- Datos de prueba automáticos en entorno de desarrollo
- Modo demo sin backend para estudios de usabilidad (`--dart-define=DEMO_MODE=true`)

---

## Limitaciones conocidas

- **El CV en PDF y el reporte mensual salen casi vacíos.** Ambos se construyen desde la
  tabla `user_activities`, pero solo la creación de publicaciones escribe en ella. Likes,
  comentarios, seguimientos, postulaciones y logins no registran actividad.
- El CV generado es un registro de actividad, no un currículum con secciones de
  educación y experiencia.
- **Supabase pausa los proyectos gratuitos tras 7 días de inactividad** y hay que
  despausarlos a mano desde el panel.

Todas están detalladas con su solución en [PRODUCCION.md](PRODUCCION.md).

---

## Diagrama de arquitectura

```
Flutter Web    ──HTTPS──►   ASP.NET Core 8    ──►  PostgreSQL (Supabase)
  (Netlify)                  (host Docker)     │
      │                            │           └──►  Supabase Storage
      │                            │
      └────WebSocket────►    SignalR Hub  ──►  clientes conectados
```
