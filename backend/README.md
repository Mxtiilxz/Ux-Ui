# Kairos — Backend

API REST construida con **.NET 8** siguiendo **Clean Architecture**. Expone endpoints HTTP
para autenticación, feed social, ofertas laborales, mensajería y Quick Match, además de un
hub SignalR para funcionalidad en tiempo real.

---

## Arquitectura

Cuatro capas. Cada una solo puede depender de las capas internas, nunca de las externas.

```
Kairos.Domain          ← Entidades y enums. Sin dependencias externas.
Kairos.Application     ← Casos de uso (CQRS con MediatR). Solo conoce Domain.
Kairos.Infrastructure  ← EF Core, JWT, Storage, PDF. Implementa las interfaces de Application.
Kairos.API             ← Controllers, SignalR Hub, middlewares. Punto de entrada.
```

- **Domain** contiene las entidades puras (`User`, `Post`, `JobPosting`, `Skill`…) sin
  lógica de framework.
- **Application** define los casos de uso como `Commands` y `Queries`. Habla con la base de
  datos solo a través de `IApplicationDbContext`, nunca directamente con EF Core.
- **Infrastructure** es la única capa que sabe conectarse a Postgres, al almacenamiento de
  archivos o generar un PDF. Esto se puso a prueba al migrar de MySQL a PostgreSQL: solo
  cambiaron el paquete del proveedor y tres archivos de esta capa, sin tocar entidades,
  casos de uso ni controladores.
- **API** recibe las peticiones HTTP, las convierte en Commands/Queries y los despacha con
  MediatR.

---

## Stack tecnológico

| Componente | Tecnología |
|---|---|
| Framework | .NET 8 |
| Base de datos | PostgreSQL vía Npgsql EF Core (Supabase) |
| Patrón de aplicación | CQRS + MediatR |
| Validación | FluentValidation |
| Autenticación | JWT Bearer (HS256) |
| Almacenamiento de archivos | Supabase Storage (producción) / filesystem local (desarrollo) |
| Generación de PDF | QuestPDF |
| Tiempo real | ASP.NET Core SignalR |

---

## Modelo de datos

| Tabla | Descripción |
|---|---|
| `users` | Usuarios. Roles: `student`, `company`, `staff`. Estado: `pending`, `approved`, `rejected`. |
| `posts` | Publicaciones del feed. Tipos `general` / `event` / `job`, con contadores desnormalizados. |
| `comments` | Comentarios en publicaciones. |
| `likes` | Likes. Clave compuesta `(UserId, PostId)` para evitar duplicados a nivel de BD. |
| `follows` | Seguimiento entre usuarios. Clave compuesta `(FollowerId, FollowedId)`. |
| `job_postings` | Ofertas laborales publicadas por empresas. |
| `job_applications` | Postulaciones de estudiantes. Almacena la URL del CV generado. |
| `messages` | Mensajería directa entre usuarios. |
| `skills` | Catálogo de competencias. Categorías: `Technical`, `Language`, `Experience`. |
| `user_skills` | Competencias declaradas por cada usuario (relación binaria, sin nivel). |
| `user_activities` | Registro de acciones, usado para generar el CV y el reporte mensual. |

> ⚠️ **`user_activities` está subalimentada.** Solo `CreatePostCommandHandler` escribe en
> ella. Likes, comentarios, seguimientos, postulaciones y logins no registran actividad, por
> lo que el CV y el reporte salen casi vacíos. Ver Fase 5 de [PRODUCCION.md](../PRODUCCION.md).

Las migraciones se aplican solas al arrancar la API (`Program.cs`). El esquema completo lo
crea la migración inicial `InitPostgres`.

---

## Endpoints

Todos bajo `/api`. `Auth: Sí` significa que requieren `Authorization: Bearer <jwt>`.

### Autenticación — `/api/auth`

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `POST` | `/register` | Registro. Crea al usuario en estado `pending`. | No |
| `POST` | `/login` | Login. Retorna JWT. Rechaza cuentas `pending` o `rejected`. | No |

### Publicaciones — `/api/posts`

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `GET` | `/feed` | Feed paginado (`?page=1&pageSize=20`) | Sí |
| `POST` | `/` | Crear publicación (`general` / `event`) | Sí |
| `PUT` | `/{postId}` | Editar publicación propia | Sí |
| `DELETE` | `/{postId}` | Eliminar publicación propia | Sí |
| `POST` | `/{postId}/like` | Alternar me gusta | Sí |
| `GET` | `/{postId}/comments` | Listar comentarios | Sí |
| `POST` | `/{postId}/comments` | Comentar | Sí |

### Ofertas laborales — `/api/jobs`

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `GET` | `/` | Listar ofertas publicadas | Sí |
| `POST` | `/` | Crear oferta (empresa) | Sí |
| `GET` | `/my-postings` | Ofertas propias de la empresa | Sí |
| `PUT` | `/{id}` | Editar oferta propia | Sí |
| `DELETE` | `/{id}` | Eliminar oferta propia | Sí |
| `GET` | `/{jobId}/applications` | Ver postulantes de una oferta | Sí |
| `POST` | `/{jobId}/apply` | Postular a una oferta (estudiante) | Sí |

### Competencias y Quick Match — `/api/skills`

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `GET` | `/` | Catálogo de competencias | Sí |
| `GET` | `/candidates` | Buscar candidatos por competencias (solo empresa) | Sí |
| `GET` | `/me` | Competencias propias | Sí |
| `POST` | `/me/{skillId}` | Agregar competencia propia | Sí |
| `DELETE` | `/me/{skillId}` | Quitar competencia propia | Sí |
| `PUT` | `/me/visibility` | Activar/desactivar visibilidad en Quick Match | Sí |
| `GET` | `/company/message` | Plantilla de mensaje de contacto de la empresa | Sí |
| `PUT` | `/company/message` | Personalizar la plantilla | Sí |

### Red de contactos — `/api/network`

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `GET` | `/following` | Usuarios que sigo | Sí |
| `GET` | `/suggestions` | Sugerencias de personas | Sí |
| `POST` | `/{userId}/follow` | Seguir | Sí |
| `DELETE` | `/{userId}/follow` | Dejar de seguir | Sí |

### Mensajería — `/api/chat`

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `GET` | `/conversations` | Conversaciones del usuario | Sí |
| `GET` | `/messages/{otherUserId}` | Historial con un usuario | Sí |
| `POST` | `/messages/{receiverId}` | Enviar mensaje | Sí |

### Administración — `/api/staff`

Todos verifican el claim de rol y devuelven `403` si el usuario no es `staff`.

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `GET` | `/registration-requests` | Cuentas pendientes de aprobación | Sí (staff) |
| `POST` | `/users/{id}/approve` | Aprobar cuenta | Sí (staff) |
| `POST` | `/users/{id}/reject` | Rechazar cuenta | Sí (staff) |
| `GET` | `/users` | Listar todos los usuarios | Sí (staff) |
| `DELETE` | `/users/{id}` | Eliminar cuenta | Sí (staff) |

### Documentos y archivos

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `GET` | `/api/curriculum/me` | CV en PDF a partir de `user_activities` | Sí |
| `GET` | `/api/reports/me` | Reporte mensual de participación en PDF | Sí |
| `POST` | `/api/storage/upload` | Subir imagen o video (máx. 50 MB) | Sí |

### Operación

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `GET` | `/health` | Devuelve `{"status":"ok"}`. No consulta la base de datos, para que un fallo de BD no provoque reinicios en bucle. | No |

---

## Rate limiting

Políticas activas, configuradas en `Program.cs` y aplicadas con `[EnableRateLimiting]`.
Las peticiones rechazadas devuelven `429 Too Many Requests`.

| Endpoint | Política | Límite | Clave | Motivo |
|---|---|---|---|---|
| `POST /api/auth/login` | `login` | 5 cada 15 min | IP (localhost exento) | Evita ataques de fuerza bruta |
| `GET /api/curriculum/me` | `curriculum` | 5 cada 15 min + 20 s entre peticiones | ID de usuario | La generación con QuestPDF es costosa en CPU |
| `GET /api/skills/candidates` | `quickmatch-search` | 30 cada 5 min | ID de usuario | La búsqueda cruza competencias en memoria |

### Pendientes recomendados

Sin implementar. Ordenados por prioridad:

| Endpoint | Límite propuesto | Clave | Motivo |
|---|---|---|---|
| `POST /api/auth/register` | 3 por hora | IP | Evita creación automatizada de cuentas |
| `POST /api/storage/upload` | 20 por hora | Usuario | Cada archivo puede pesar 50 MB |
| `GET /api/reports/me` | 5 cada 15 min | Usuario | Mismo costo de renderizado que el CV |
| `POST /api/posts` | 10 cada 10 min | Usuario | Evita saturar el feed |
| `POST /api/posts/{id}/comments` | 20 cada 10 min | Usuario | Evita inundar una publicación |
| `POST /api/jobs/{id}/apply` | 10 por hora | Usuario | Las postulaciones son acciones deliberadas |
| `POST /api/chat/messages/{id}` | 30 por minuto | Usuario | Evita hostigamiento por mensajes |
| `POST /api/network/{id}/follow` | 50 por hora | Usuario | Evita seguimiento masivo automatizado |

---

## Hubs SignalR

Ambas rutas montan la misma clase `SocialHub`. Para conectarse, incluir el JWT en el query
string: `?access_token=<token>`.

- `/hubs/chat` — usado por el cliente Flutter para mensajería directa.
- `/hubs/social` — usado para notificaciones sociales.

| Evento (cliente → servidor) | Descripción |
|---|---|
| `JoinPostComments(postId)` | Unirse al grupo de comentarios de un post |
| `LeavePostComments(postId)` | Salir del grupo |
| `SendComment(postId, content)` | Enviar comentario en tiempo real |
| `SendTyping(postId)` | Emitir indicador "está escribiendo…" |
| `JoinConversation(myId, peerId)` | Entrar a una conversación directa |
| `SendDirectMessage(senderId, peerId, content)` | Enviar mensaje directo |

| Evento (servidor → cliente) | Descripción |
|---|---|
| `ReceiveMessage` | Mensaje directo nuevo |
| `ReceiveComment` | Comentario nuevo en el post que se está viendo |
| `ReceiveLike` | Like en una publicación propia |
| `ReceiveFollow` | Nuevo seguidor |
| `UserTyping` | Alguien está escribiendo |

---

## Cómo levantar el backend

### Requisitos previos

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8)
- PostgreSQL 14+ corriendo localmente
- EF Core CLI: `dotnet tool install --global dotnet-ef --version 8.*`

### 1. Configurar PostgreSQL

```sql
CREATE DATABASE kairos;
CREATE USER kairos_user WITH PASSWORD 'tu_password';
GRANT ALL PRIVILEGES ON DATABASE kairos TO kairos_user;
```

### 2. Configurar appsettings

Editar **solo** `src/Kairos.API/appsettings.Development.json` con la cadena de conexión
local:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=kairos;Username=kairos_user;Password=tu_password"
  }
}
```

> 🔒 **`appsettings.json` no contiene secretos y debe seguir así** — está versionado en git.
> En producción todo llega por variables de entorno
> (`ConnectionStrings__DefaultConnection`, `Jwt__SecretKey`, `Supabase__ServiceKey`).
> Ver [PRODUCCION.md](../PRODUCCION.md).

> En modo `Development`, `DependencyInjection.cs` registra `LocalStorageService` (guarda en
> `wwwroot/uploads`) en vez de Supabase Storage. Para desarrollo local **no necesitas una
> cuenta de Supabase**.

### 3. Aplicar migraciones

Desde `backend/`:

```bash
dotnet ef database update --startup-project src/Kairos.API --project src/Kairos.Infrastructure
```

Paso opcional: también se aplican solas al arrancar la API.

### 4. Correr la API

```bash
dotnet run --project src/Kairos.API
```

Queda en `http://localhost:5001` (puerto fijado en `appsettings.Development.json`).
Swagger UI: `http://localhost:5001/swagger`.

Para los endpoints protegidos, primero hacer login con `/api/auth/login`, copiar el JWT y
pegarlo en el botón **Authorize** (candado) de Swagger.

En modo `Development` el seeder crea usuarios de prueba automáticamente — credenciales en
el [README raíz](../README.md).

---

## Solución de problemas comunes

| Error | Causa probable | Solución |
|---|---|---|
| `password authentication failed for user` | Credenciales viejas en `appsettings.Development.json` | Actualizar la cadena de conexión |
| `Falta la clave JWT` al arrancar | No hay `Jwt:SecretKey` en configuración | Definirla en `appsettings.Development.json` o exportar `Jwt__SecretKey` |
| `prepared statement already exists` en producción | La cadena apunta al Transaction pooler de Supabase (puerto 6543) | Usar el Session pooler (puerto 5432) |
| `Unable to retrieve project metadata` | Comando ejecutado desde la carpeta incorrecta | Ejecutarlo desde `backend/` |
| `dotnet-ef not found` | La herramienta no está en el PATH | Agregar `$HOME/.dotnet/tools` al PATH |
| `Some services are not able to be constructed` | Servicio no registrado en DI | Revisar `DependencyInjection.cs` en `Kairos.Infrastructure` |
| Error CORS desde Flutter web | El frontend no apunta al backend local, o su puerto no está en la whitelist de `Program.cs` | Correr el frontend con `--dart-define=API_URL=http://localhost:5001/api` |
| `401` en todas las peticiones tras registrarse | La cuenta quedó en estado `pending` | Aprobarla con un usuario `staff` desde el panel de administración |
