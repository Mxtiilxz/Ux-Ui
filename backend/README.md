# Kairos — Backend

API REST en .NET 8 con Clean Architecture. Expone endpoints HTTP para autenticación, feed
social, ofertas laborales, mensajería y Quick Match, más un hub SignalR para tiempo real.

## Arquitectura

Cuatro capas. Cada una depende solo de las interiores.

```
Kairos.Domain          Entidades y enums. Sin dependencias externas.
Kairos.Application     Casos de uso (CQRS con MediatR). Solo conoce Domain.
Kairos.Infrastructure  EF Core, JWT, Storage, PDF. Implementa las interfaces de Application.
Kairos.API             Controllers, SignalR, middleware. Punto de entrada.
```

**Application** habla con la base de datos solo a través de `IApplicationDbContext`, nunca
con EF Core directamente. **Infrastructure** es la única capa que conoce Postgres, el
almacenamiento de archivos o la generación de PDF; esa separación se puso a prueba al
migrar de MySQL a PostgreSQL, donde solo cambiaron el paquete del proveedor y tres archivos
de esa capa, sin tocar entidades, casos de uso ni controladores.

## Stack

| Componente | Tecnología |
|---|---|
| Framework | .NET 8 |
| Base de datos | PostgreSQL vía Npgsql EF Core |
| Patrón | CQRS + MediatR |
| Validación | FluentValidation |
| Autenticación | JWT Bearer HS256 |
| Archivos | Supabase Storage en producción, filesystem local en desarrollo |
| PDF | QuestPDF |
| Tiempo real | ASP.NET Core SignalR |

## Modelo de datos

Catorce tablas. Las migraciones se aplican solas al arrancar la API.

| Tabla | Descripción |
|---|---|
| `users` | Roles `student`, `company`, `staff`. Estados `pending`, `approved`, `rejected`. Incluye las preferencias de privacidad y la visibilidad en Quick Match. |
| `posts` | Publicaciones del feed. Tipos `general`, `event` y `job`, con contadores desnormalizados. |
| `comments` | Comentarios en publicaciones. |
| `likes` | Clave compuesta `(UserId, PostId)`, que impide duplicados en la base. |
| `follows` | Conexiones bilaterales. `FollowerId` solicita, `FollowedId` responde; `Status` distingue `pending` de `accepted`. |
| `job_postings` | Ofertas publicadas por empresas. |
| `job_posting_skills` | Competencias que solicita cada oferta. Es lo que hace medible la demanda. |
| `job_applications` | Postulaciones. Guarda la URL del CV. |
| `saved_jobs` | Ofertas guardadas por un usuario. |
| `messages` | Mensajería directa. |
| `skills` | Catálogo curado. Categorías `Technical`, `Language` y `Experience`. |
| `user_skills` | Competencias declaradas por cada usuario, sin nivel de dominio. |
| `cv_entries` | Formación y experiencia del currículum. |
| `user_activities` | Bitácora de uso, empleada por el reporte mensual. |

`user_activities` está subalimentada: solo `CreatePostCommandHandler` escribe en ella, así
que el reporte mensual refleja una fracción de la actividad real. No afecta al currículum,
que se construye desde `cv_entries` y el perfil.

## Endpoints

Todos bajo `/api`. Salvo el registro, el login y `/health`, todos exigen
`Authorization: Bearer <jwt>`.

### Autenticación — `/api/auth`

| Método | Ruta | Descripción |
|---|---|---|
| `POST` | `/register` | Registro público. Un alumno queda `pending`; una empresa entra aprobada. El rol staff no se acepta. |
| `POST` | `/login` | Devuelve el JWT. Informa por separado si la cuenta espera aprobación. |

### Publicaciones — `/api/posts`

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/feed` | Feed paginado, filtrado por las preferencias de privacidad de cada autor |
| `POST` | `/` | Crear publicación |
| `PUT` | `/{postId}` | Editar publicación propia |
| `DELETE` | `/{postId}` | Eliminar publicación propia |
| `POST` | `/{postId}/like` | Alternar me gusta |
| `GET` | `/{postId}/comments` | Listar comentarios |
| `POST` | `/{postId}/comments` | Comentar |

### Ofertas laborales — `/api/jobs`

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/` | Listar ofertas abiertas |
| `POST` | `/` | Crear oferta con sus competencias (empresa) |
| `GET` | `/my-postings` | Ofertas propias |
| `PUT` | `/{id}` | Editar oferta propia |
| `DELETE` | `/{id}` | Eliminar oferta propia |
| `GET` | `/{jobId}/applications` | Postulantes de una oferta |
| `POST` | `/{jobId}/apply` | Postular |
| `GET` | `/saved` | Ofertas guardadas |
| `POST` | `/{jobId}/save` | Alternar guardado |

### Competencias y Quick Match — `/api/skills`

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/` | Catálogo |
| `GET` | `/catalog` | Catálogo con uso, para el panel de staff |
| `POST` | `/` | Agregar competencia al catálogo (staff) |
| `DELETE` | `/{skillId}` | Retirar del catálogo (staff) |
| `GET` | `/candidates` | Buscar candidatos por competencias (empresa) |
| `GET` | `/me` | Competencias propias |
| `POST` | `/me/{skillId}` | Agregar competencia propia |
| `DELETE` | `/me/{skillId}` | Quitar competencia propia |
| `PUT` | `/me/visibility` | Activar o desactivar la visibilidad en Quick Match |
| `GET` `/` `PUT` | `/company/message` | Plantilla de contacto de la empresa |

### Red de contactos — `/api/network`

Las conexiones son bilaterales: enviar una solicitud no crea el vínculo hasta que la otra
parte responde.

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/connections` | Contactos conectados |
| `GET` | `/following` | Alias de `/connections`, conservado para la pestaña de chat |
| `GET` | `/requests` | Solicitudes recibidas sin responder |
| `GET` | `/suggestions` | Personas sugeridas. Excluye al staff y a quien ya tenga relación en curso |
| `POST` | `/{userId}/connect` | Enviar solicitud. Si la otra persona ya había enviado una, se acepta |
| `POST` | `/requests/{userId}/accept` | Aceptar |
| `POST` | `/requests/{userId}/reject` | Rechazar |
| `DELETE` | `/{userId}/connect` | Deshacer la conexión o retirar la solicitud |

### Perfil — `/api/users`

| Método | Ruta | Descripción |
|---|---|---|
| `GET` `/` `PUT` | `/me` | Consultar y editar el perfil propio |
| `GET` `/` `PUT` | `/me/privacy` | Quién puede escribirle y quién ve sus publicaciones |
| `GET` | `/me/cv-entries` | Formación y experiencia |
| `POST` | `/me/cv-entries` | Agregar una entrada |
| `DELETE` | `/me/cv-entries/{id}` | Eliminar una entrada |

### Mensajería — `/api/chat`

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/conversations` | Conversaciones del usuario |
| `GET` | `/messages/{otherUserId}` | Historial con una persona |
| `POST` | `/messages/{receiverId}` | Enviar mensaje |

### Administración — `/api/staff`

Verifican el rol y devuelven `403` a quien no sea staff.

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/registration-requests` | Cuentas pendientes |
| `GET` | `/pending-count` | Cantidad pendiente, para la insignia del panel |
| `POST` | `/users/{id}/approve` | Aprobar |
| `POST` | `/users/{id}/reject` | Rechazar |
| `GET` | `/users` | Listar usuarios |
| `POST` | `/users` | Crear una cuenta ya aprobada, incluida otra de staff |
| `DELETE` | `/users/{id}` | Eliminar cuenta |
| `GET` | `/join-history` | Historial de altas |

### Documentos, estadísticas y operación

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/curriculum/me` | Currículum en PDF, construido desde el perfil |
| `GET` | `/api/reports/me` | Reporte mensual de participación en PDF |
| `GET` | `/api/stats/community` | Cifras del feed: oferta y demanda de competencias |
| `POST` | `/api/storage/upload` | Subir imagen o video, hasta 50 MB |
| `GET` | `/health` | `{"status":"ok"}`. No consulta la base de datos, para que un fallo de esta no provoque reinicios en bucle |

## Formato de errores

Las excepciones se traducen a `application/problem+json` según RFC 7807 en
`ExceptionHandlingMiddleware`.

| Excepción | Estado |
|---|---|
| `ValidationException`, `ArgumentException` | 400 |
| `UnauthorizedAccessException` | 401 |
| `AccountNotApprovedException`, `ForbiddenException` | 403 |
| `KeyNotFoundException` | 404 |
| `InvalidOperationException` | 409 |
| `DbUpdateException` y el resto | 500 |

El 409 merece atención: EF Core lanza `InvalidOperationException` cuando no puede traducir
una consulta LINQ a SQL, un fallo que no aparece al compilar y solo se manifiesta al
ejecutar. Los tests de `tests/Kairos.Application.Tests` cubren ese caso.

## Rate limiting

Configurado en `Program.cs` y aplicado con `[EnableRateLimiting]`. Las peticiones
rechazadas devuelven `429`.

| Endpoint | Límite | Clave | Motivo |
|---|---|---|---|
| `POST /api/auth/login` | 5 cada 15 min | IP, localhost exento | Fuerza bruta |
| `GET /api/curriculum/me` | 5 cada 15 min, con 20 s entre peticiones | Usuario | Renderizar con QuestPDF cuesta CPU |
| `GET /api/skills/candidates` | 30 cada 5 min | Usuario | La búsqueda cruza competencias en memoria |

Conviene extenderlo al registro, la subida de archivos, el reporte mensual y las acciones
de escritura del feed y del chat.

## Hubs SignalR

Ambas rutas montan la clase `SocialHub`. El JWT viaja en el query string como
`?access_token=<token>`.

- `/hubs/chat` para mensajería directa.
- `/hubs/social` para notificaciones sociales.

| Cliente a servidor | Descripción |
|---|---|
| `JoinPostComments(postId)` | Unirse al grupo de comentarios |
| `LeavePostComments(postId)` | Salir del grupo |
| `SendComment(postId, content)` | Comentar |
| `SendTyping(postId)` | Indicador de escritura |
| `JoinConversation(myId, peerId)` | Entrar a una conversación |
| `SendDirectMessage(senderId, peerId, content)` | Enviar mensaje |

| Servidor a cliente | Descripción |
|---|---|
| `ReceiveMessage` | Mensaje directo nuevo |
| `ReceiveComment` | Comentario en el post que se está viendo |
| `ReceiveLike` | Me gusta en una publicación propia |
| `ReceiveFollow` | Solicitud de conexión |
| `UserTyping` | Alguien está escribiendo |

## Ejecución local

Requiere .NET 8 SDK, PostgreSQL 14 o superior y el CLI de EF Core
(`dotnet tool install --global dotnet-ef --version 8.*`).

```sql
CREATE DATABASE kairos;
CREATE USER kairos_user WITH PASSWORD 'tu_password';
GRANT ALL PRIVILEGES ON DATABASE kairos TO kairos_user;
```

La cadena de conexión va en `src/Kairos.API/appsettings.Development.json`, no en
`appsettings.json`, que está versionado y no debe contener secretos. En `Development` se
registra `LocalStorageService`, que guarda en `wwwroot/uploads`, de modo que no hace falta
una cuenta de Supabase.

```bash
dotnet run --project src/Kairos.API
```

Queda en `http://localhost:5001` con Swagger en `/swagger`. Para probar endpoints
protegidos, hacer login, copiar el JWT y pegarlo en el botón Authorize.

## Tests

```bash
dotnet test
```

`tests/Kairos.Application.Tests` comprueba que las consultas del feed y de la red se
traducen a SQL de PostgreSQL. No necesita base de datos: EF traduce al construir la
consulta, así que `ToQueryString()` lanza la misma excepción que lanzaría el servidor.

El proyecto está en la solución pero fuera de la imagen Docker. Por eso el `Dockerfile`
restaura `src/Kairos.API/Kairos.API.csproj` y no la solución completa: `dotnet restore` a
secas intentaría resolver también el proyecto de tests, cuyo `.csproj` no se copia, y la
compilación fallaría.

## Problemas frecuentes

| Error | Causa | Solución |
|---|---|---|
| `password authentication failed for user` | Credenciales desactualizadas | Revisar `appsettings.Development.json` |
| `Falta la clave JWT` al arrancar | No hay `Jwt:SecretKey` | Definirla en configuración o exportar `Jwt__SecretKey` |
| `prepared statement already exists` | La cadena usa el Transaction pooler de Supabase (6543) | Usar el Session pooler (5432) |
| `Unable to retrieve project metadata` | Comando lanzado desde otra carpeta | Ejecutarlo desde `backend/` |
| `dotnet-ef not found` | La herramienta no está en el PATH | Agregar `$HOME/.dotnet/tools` |
| Error CORS desde Flutter web | El origen no está en la lista de `Program.cs` | Correr el frontend con `--dart-define=API_URL=http://localhost:5001/api` |
| `401` tras registrarse | La cuenta quedó `pending` | Aprobarla desde el panel con una cuenta de staff |
| `409` en un endpoint de lectura | Consulta LINQ no traducible | Filtrar y ordenar antes de proyectar, y cubrirlo con un test |
