- [ ] Llenar `appsettings.json` con credenciales **reales** de Azure Blob Storage
  (`AccountName`, `AccountKey`) + URL del CDN. El esquema de MySQL ya no es un
  pendiente: las migraciones EF Core existen y se aplican solas al arrancar la
  API (`Program.cs`). Nota: en modo `Development` esto no bloquea nada — el
  backend usa almacenamiento local automáticamente (`LocalStorageService`).
  Solo afecta la subida de archivos en producción (Railway).

- [x] Crear el servicio de generador de currículum — implementado
  (`CurriculumController`, `GenerateCurriculumQueryHandler`, `CurriculumGeneratorService`
  con QuestPDF). Genera un PDF a partir del historial de `UserActivity` del
  usuario. Pendiente de decisión de producto: hoy es un log de actividad, no
  un CV tradicional con secciones de educación/experiencia/habilidades — se
  necesitarían nuevos campos en `User` si se quiere ese formato.

- [x] Error CORS en `/api/auth/register` — resuelto en el backend (whitelist de
  orígenes en `Program.cs` incluye `localhost:3000/5000/8080`, orden de
  middleware correcto). Si vuelve a aparecer, la causa más probable es que el
  frontend no se está corriendo con
  `--dart-define=API_URL=http://localhost:5001/api` (sin ese flag, apunta al
  backend de producción) — ver tabla de troubleshooting en `backend/README.md`.

- [x] Tipos de post general/event/job — backend completo (enum `PostType`,
  autorización por rol en `CreatePostCommandHandler`, validación de
  `EventDate` obligatoria para eventos). En el frontend, el botón "Evento" del
  compositor ya está conectado (`home_page.dart`, `_promptEventDate` /
  `_publishEventPost`). Se decidió **no** exponer la creación de posts tipo
  `job` desde el frontend — las ofertas laborales siguen usando el sistema
  separado `JobPosting`/`/api/jobs`, ya funcional.
