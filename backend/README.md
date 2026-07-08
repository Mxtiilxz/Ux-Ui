# Kairos — Backend

API REST construida con **.NET 8** siguiendo **Clean Architecture**. Expone endpoints HTTP para autenticación, publicaciones y almacenamiento, además de un hub SignalR para funcionalidad en tiempo real.

---

## Arquitectura

El proyecto está dividido en cuatro capas. Cada una solo puede depender de las capas internas, nunca de las externas.

```
Kairos.Domain          ← Entidades y enums. Sin dependencias externas.
Kairos.Application     ← Casos de uso (CQRS con MediatR). Solo conoce Domain.
Kairos.Infrastructure  ← Base de datos, JWT, Azure Blob, PDF. Implementa las interfaces de Application.
Kairos.API             ← Controllers, SignalR Hub, middlewares. Punto de entrada de la app.
```

### ¿Por qué esta estructura?

- **Domain** contiene las entidades puras (`User`, `Post`, `JobPosting`, etc.) sin lógica de framework.
- **Application** define los casos de uso como `Commands` y `Queries` (patrón CQRS). Habla con la base de datos solo a través de la interfaz `IApplicationDbContext`, nunca directamente con EF Core.
- **Infrastructure** es la única capa que sabe cómo conectarse a MySQL, Azure Blob o generar un PDF. Si algún día se cambia la base de datos, solo esta capa cambia.
- **API** recibe las peticiones HTTP, las convierte en Commands/Queries y los despacha con MediatR.

---

## Stack tecnológico

| Componente | Tecnología |
|---|---|
| Framework | .NET 8 |
| Base de datos | MySQL 8.0 vía Pomelo EF Core |
| Patrón de aplicación | CQRS + MediatR |
| Validación | FluentValidation |
| Autenticación | JWT Bearer (HS256) |
| Almacenamiento de archivos | Azure Blob Storage |
| Generación de PDF | QuestPDF |
| Tiempo real | ASP.NET Core SignalR |

---

## Estructura de la base de datos

| Tabla | Descripción |
|---|---|
| `Users` | Usuarios del sistema. Soporta tres roles: `Student`, `Company`, `Backoffice`. |
| `Posts` | Publicaciones del feed. Incluye contadores desnormalizados de likes y comentarios. |
| `Comments` | Comentarios en publicaciones. |
| `Likes` | Likes a publicaciones. Clave compuesta `(UserId, PostId)` para evitar duplicados a nivel de BD. |
| `Follows` | Relación de seguimiento entre usuarios. Clave compuesta `(FollowerId, FollowedId)`. |
| `JobPostings` | Ofertas laborales publicadas por empresas. |
| `JobApplications` | Postulaciones de estudiantes a ofertas. Almacena la URL del CV generado. |
| `UserActivities` | Registro de acciones del usuario, usado para generar el CV automático. |

---

## Endpoints disponibles

### Autenticación

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `POST` | `/api/auth/register` | Registro de nuevo usuario | No |
| `POST` | `/api/auth/login` | Login. Retorna JWT. | No |

### Publicaciones

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `GET` | `/api/posts/feed` | Feed paginado (`?page=1&pageSize=20`) | Sí |
| `POST` | `/api/posts` | Crear publicación | Sí |

### Almacenamiento

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `POST` | `/api/storage/upload` | Subir imagen o video a Azure Blob (máx. 50 MB) | Sí |

### Reportes

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `GET` | `/api/curriculum/me` | Descargar CV en PDF generado a partir de actividades | Sí |

---

## Hub SignalR — `/hubs/social`

Para conectarse, incluir el JWT en el query string: `?access_token=<token>`

| Evento (cliente → servidor) | Descripción |
|---|---|
| `JoinPostComments(postId)` | Unirse al grupo de comentarios de un post |
| `LeavePostComments(postId)` | Salir del grupo |
| `SendComment(postId, content)` | Enviar comentario en tiempo real |
| `SendTyping(postId)` | Emitir indicador "está escribiendo..." |

| Evento (servidor → cliente) | Descripción |
|---|---|
| `ReceiveComment` | Nuevo comentario en el post que se está viendo |
| `ReceiveLike` | Notificación de like en una publicación propia |
| `ReceiveFollow` | Notificación de nuevo seguidor |
| `UserTyping` | Alguien está escribiendo en los comentarios |

---

## Cómo levantar el backend

### Requisitos previos

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8)
- MySQL 8.0 corriendo localmente
- Herramienta EF Core CLI:
  ```bash
  dotnet tool install --global dotnet-ef --version 8.*
  ```

---

### 1. Configurar MySQL

```sql
CREATE DATABASE kairos;
CREATE USER 'kairos_user'@'localhost' IDENTIFIED BY 'tu_password';
GRANT ALL PRIVILEGES ON kairos.* TO 'kairos_user'@'localhost';
FLUSH PRIVILEGES;
```

---

### 2. Configurar appsettings

Editar `src/Kairos.API/appsettings.json` y `appsettings.Development.json` con los valores reales:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Port=3306;Database=kairos;User=kairos_user;Password=tu_password;"
  },
  "Jwt": {
    "SecretKey": "clave-secreta-de-al-menos-32-caracteres"
  },
  "AzureBlob": {
    "ConnectionString": "UseDevelopmentStorage=true",
    "ContainerName": "kairos-media-dev",
    "CdnBaseUrl": "http://127.0.0.1:10000/devstoreaccount1/kairos-media-dev"
  }
}
```

> En modo `Development`, `DependencyInjection.cs` registra `LocalStorageService`
> (guarda archivos en `wwwroot/uploads`) en vez de Azure Blob, sin importar lo
> que digan estos valores — así que para desarrollo local **no necesitás
> Azurite ni una cuenta de Azure real**, podés dejar los valores tal cual. Estos
> valores solo importan cuando `ASPNETCORE_ENVIRONMENT` no es `Development`
> (por ejemplo en producción, donde sí se usa Azure Blob real).

---

### 3. Aplicar migraciones

Desde la carpeta `backend/`:

```bash
dotnet ef database update --startup-project src/Kairos.API
```

Esto crea todas las tablas en MySQL.

Si por alguna razón necesitás regenerar la migración desde cero:

```bash
dotnet ef migrations add Init --project src/Kairos.Infrastructure --startup-project src/Kairos.API
dotnet ef database update --startup-project src/Kairos.API
```

---

### 4. Correr la API

```bash
dotnet run --project src/Kairos.API
```

La terminal mostrará la URL donde está escuchando. En modo `Development` es
`http://localhost:5001` (fijado en `appsettings.Development.json`, sección `Urls`).

Abrí **Swagger UI** en el navegador:

```
http://localhost:5001/swagger
```

Desde ahí podés probar todos los endpoints directamente. Para los endpoints protegidos, primero hacé login con `/api/auth/login`, copiá el token JWT de la respuesta y pegalo en el botón **Authorize** (ícono del candado) en Swagger.

---

### Solución de problemas comunes

| Error | Causa probable | Solución |
|---|---|---|
| `Access denied for user 'root'@'localhost'` | `appsettings.Development.json` tiene credenciales viejas | Actualizar la connection string en ese archivo |
| `Unable to retrieve project metadata` | Comando ejecutado desde la carpeta incorrecta | Asegurarse de estar en la carpeta `backend/` |
| `dotnet-ef not found` | La herramienta no está en PATH | Agregar `export PATH=$PATH:$HOME/.dotnet/tools` al `.bashrc` |
| `Some services are not able to be constructed` | Servicio no registrado en DI | Verificar `DependencyInjection.cs` en `Kairos.Infrastructure` |
| Error CORS al llamar `/api/auth/register` u otro endpoint desde Flutter web | El frontend no está apuntando al backend local, o corre en un puerto no incluido en la whitelist de `Program.cs` (`UseCors`) | Correr el frontend con `flutter run -d web-server --web-port=3000 --dart-define=API_URL=http://localhost:5001/api` — sin el `--dart-define`, `ApiClient` apunta por defecto al backend de producción en Railway |
