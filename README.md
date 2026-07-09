# Kairos

Red social para estudiantes técnico-profesionales de liceos técnicos. Conecta alumnos con empresas, prácticas profesionales y la comunidad de su área.

**app en producción:** [https://kairoslt.netlify.app](https://kairoslt.netlify.app)

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Frontend | Flutter 3 (web + mobile) |
| Backend | ASP.NET Core 8 — Clean Architecture (CQRS + MediatR) |
| Base de datos | MySQL 8.0 via Pomelo EF Core |
| Almacenamiento | Azure Blob Storage (producción) / filesystem local (dev) |
| Tiempo real | ASP.NET Core SignalR |
| Generación PDF | QuestPDF |
| Autenticación | JWT Bearer HS256 |
| Rate limiting | ASP.NET Core Rate Limiter |
| Deploy backend | Railway |
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
        │   ├── api/                # ApiClient (Dio + JWT interceptor)
        │   ├── models/             # UserProfile, etc.
        │   ├── services/           # SocialHubService (SignalR)
        │   ├── theme/              # AppColors, KairosPalette
        │   └── widgets/            # KCard, PostCard y widgets compartidos
        └── features/
            ├── auth/               # Login y registro
            ├── home/               # Feed principal
            ├── profile/            # Perfil de usuario con edición y CV PDF
            ├── jobs/               # Ofertas laborales (empresa y estudiante)
            ├── network/            # Red de contactos
            ├── chat/               # Mensajería
            └── staff/              # Panel de administración (aprobación, usuarios)
```

---

## Requisitos previos

### Backend
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8)
- MySQL 8.0 corriendo localmente

### Frontend
- [Flutter 3.x](https://docs.flutter.dev/get-started/install) con soporte web habilitado

---

## Instrucciones para ejecutar el proyecto localmente

### 1. Base de datos

Crear la base de datos y el usuario en MySQL:

```sql
CREATE DATABASE kairos;
CREATE USER 'kairos_user'@'localhost' IDENTIFIED BY 'kairos2026';
GRANT ALL PRIVILEGES ON kairos.* TO 'kairos_user'@'localhost';
FLUSH PRIVILEGES;
```

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
> - Estudiante: `kairos_user1@kairos.cl` (Ana González Rojas — ya tiene
>   competencias cargadas y visibilidad en Quick Match activada)
> - Staff: `staff1@kairos.cl` / `staff2@kairos.cl`
> - Empresa: `empresa@kairos.cl` (Automatización Industrial S.A.) /
>   `empresa2@kairos.cl` (TechSolutions Chile SpA)

> En modo `Development` la subida de archivos usa el filesystem local
> automáticamente (`LocalStorageService`) — **no necesitas Azure Blob ni
> Azurite para desarrollar localmente**, esos valores solo importan en
> producción.

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

Configurar en `appsettings.json` o como variables de entorno en Railway:

| Variable | Descripción |
|---|---|
| `ConnectionStrings__DefaultConnection` | Cadena de conexión MySQL |
| `Jwt__SecretKey` | Clave secreta JWT (mínimo 32 caracteres) |
| `Jwt__Issuer` | Emisor del token (ej. `kairos-api`) |
| `Jwt__Audience` | Audiencia del token (ej. `kairos-app`) |
| `AzureBlob__ConnectionString` | Cadena de conexión Azure Blob Storage |
| `AzureBlob__ContainerName` | Nombre del contenedor (ej. `kairos-media`) |
| `AzureBlob__CdnBaseUrl` | URL base del CDN o del contenedor público |

---

## Despliegue

### Backend → Railway

1. Conectar el repositorio en [railway.app](https://railway.app)
2. Railway detecta el `Dockerfile` en `/backend/` automáticamente
3. Agregar un plugin MySQL en Railway o conectar una BD externa
4. Configurar las variables de entorno listadas arriba

### Frontend → Netlify

```bash
cd frontend
flutter build web
netlify deploy --prod --dir=build/web
```

---

## Funcionalidades implementadas

- Registro e inicio de sesión con JWT (estudiante, staff, empresa)
- Feed social con publicaciones, likes y comentarios en tiempo real (SignalR)
- Subida de imágenes para posts y publicaciones de empleo
- Gestión de ofertas laborales: crear, editar, eliminar y ver postulantes
- Postulación a ofertas de empleo
- **Quick Match**: los estudiantes registran sus competencias (técnicas,
  idiomas, experiencia) y activan su visibilidad; las empresas buscan
  candidatos por competencia desde la pestaña Trabajos, ven el % de
  coincidencia y contactan directo por chat con un mensaje automático
- Red de contactos (seguir / dejar de seguir usuarios)
- Mensajería en tiempo real
- Perfil de usuario editable con foto de perfil
- Generación de CV en PDF
- Panel de administración de usuarios para staff
- Importación de alumnos vía CSV
- Persistencia de sesión en web (localStorage vía flutter_secure_storage)
- Rate limiting en endpoints sensibles (login, generación de CV, búsqueda de Quick Match)
- Datos de prueba automáticos en entorno de desarrollo

---

## Diagrama de arquitectura

```
Flutter Web  ──HTTPS──►  ASP.NET Core 8 (Railway)  ──►  MySQL 8 (Railway)
    │                          │
    │                          └──►  Azure Blob Storage
    │
    └──WebSocket──►  SignalR Hub  ──►  clientes conectados
```
