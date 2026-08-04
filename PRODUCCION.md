# Plan de paso a producción — Kairos

Este documento define cómo llevar Kairos de la demo en memoria (`DEMO_MODE`) a una
aplicación funcional con base de datos real, accesos restringidos y persistencia de
publicaciones, comentarios, likes e interacciones.

---

## 1. Punto de partida

**Lo que ya está construido y funciona** (no requiere trabajo nuevo):

| Capa | Estado |
|---|---|
| Autenticación JWT + BCrypt | ✅ `AuthController`, `JwtService` |
| Roles `student` / `company` / `staff` | ✅ claim `ClaimTypes.Role`, verificado por endpoint |
| Flujo de aprobación de cuentas | ✅ `pending` → `approved` / `rejected` (`StaffController`) |
| Publicaciones, likes, comentarios | ✅ entidades + endpoints en `PostsController` |
| Red de contactos (seguir) | ✅ `Follow`, `NetworkController` |
| Ofertas y postulaciones | ✅ `JobPosting`, `JobApplication`, `JobsController` |
| Mensajería | ✅ `Message`, `ChatController` + SignalR |
| Quick Match (competencias) | ✅ `Skill`, `UserSkill`, `SkillsController` |
| Migraciones EF Core | ✅ 5 migraciones, se aplican solas al arrancar |
| Rate limiting | ✅ login, currículum, búsqueda Quick Match |
| Dockerfile del backend | ✅ `backend/Dockerfile`, listo para desplegar |

**El estado real del despliegue:**

- La API en Railway está **caída** — devuelve `404 Application not found`.
- La base de datos MySQL de Railway **sigue existiendo** (el puerto `47214` responde).
- El frontend en Netlify corre con `DEMO_MODE=true`: todo es en memoria y se pierde al recargar.

---

## 2. Brechas que hay que cerrar

### 🔴 Bloqueantes

**B1. Los secretos están en el repositorio.**
`backend/src/Kairos.API/appsettings.json` tiene commiteada la contraseña real de MySQL y
la clave de firma JWT. Están en el historial de git. Hay que moverlos a variables de
entorno **y rotar ambos**, porque el valor antiguo ya no es secreto.

**B2. Bloqueo de aprobación en producción.**
`RegisterCommandHandler` crea todo usuario con `Status = "pending"`. Solo un usuario con
rol `staff` puede aprobarlo. Pero `DevDataSeeder` corre únicamente si
`app.Environment.IsDevelopment()` — o sea, **en producción no existe ningún staff y nadie
puede aprobar a nadie**. La app queda inutilizable desde el primer registro.

**B3. La subida de imágenes está rota en producción.**
`DependencyInjection.cs` elige `StorageService` (Azure Blob) fuera de desarrollo, pero
`appsettings.json` tiene credenciales de relleno (`AccountName=ACCOUNT`). Fotos de perfil
e imágenes de publicaciones fallarán. En desarrollo usa disco local, que en un contenedor
es efímero.

**B4. El frontend apunta a servidores muertos.**
- `api_client.dart:15` → URL de Railway caída.
- `chat_hub_service.dart:17` → misma URL caída.
- `social_hub_service.dart:9` → **`http://localhost:5001/hubs/social` hardcodeado**, sin
  `fromEnvironment`. Nunca funcionará fuera de tu máquina.

**B5. CORS no autoriza el dominio actual.**
La lista blanca en `Program.cs` incluye `kairoslt.netlify.app` pero no
`kairoswebapp.netlify.app`, que es el dominio en uso.

### 🟡 Importantes

**I1. El registro de interacciones está casi vacío.**
La entidad `UserActivity` existe y el generador de CV y el reporte de usuario dependen de
ella, pero **solo `CreatePostCommandHandler` escribe en ella**. Likes, comentarios,
seguimientos, postulaciones y logins no registran nada. Resultado: el CV automático y el
reporte salen prácticamente en blanco. Esto es exactamente el "almacenamiento de
interacciones" que falta.

**I2. No hay endpoint de salud.** Los hosts gratuitos necesitan `/health` para no reiniciar
el contenedor por error.

**I3. `DEMO_MODE` debe conservarse, no borrarse.** Es un flag de compilación y sirve para
futuros estudios de usabilidad sin depender del servidor.

### 🟢 Deseables (no bloquean)

- Verificación de correo al registrarse.
- Refresh tokens (hoy el JWT dura 24 h fijas y no se puede revocar).
- Respaldos automáticos de la base de datos.

---

## 3. Opciones de hosting

El backend es un contenedor Docker de .NET 8 y necesita MySQL, almacenamiento de archivos
y estar siempre disponible.

### Opción A — Railway (recomendada si aceptas ~$5 USD/mes)

| Pieza | Servicio | Costo |
|---|---|---|
| API | Railway (Dockerfile ya listo) | Plan Hobby $5/mes, incluye $5 de consumo |
| Base de datos | Railway MySQL (**ya existe**) | incluido en el consumo |
| Imágenes | Volumen persistente de Railway | incluido |
| Frontend | Netlify | gratis |

**Por qué:** cero código nuevo para almacenamiento, la base de datos ya está creada con las
migraciones aplicadas, y el redespliegue es automático desde GitHub. Es el camino más corto
a una app funcional.

**Contra:** es el único que cuesta dinero.

### Opción B — Todo gratis

| Pieza | Servicio | Límite |
|---|---|---|
| API | Koyeb free | 1 servicio, no duerme |
| Base de datos | TiDB Cloud Serverless | compatible MySQL, 5 GB, sin expiración |
| Imágenes | Cloudinary free | 25 GB — requiere un `IStorageService` nuevo |
| Frontend | Netlify | gratis |

**Por qué:** costo cero real y sin fecha de vencimiento.

**Contra:** tres proveedores distintos que administrar, y hay que escribir
`CloudinaryStorageService`. Alternativa a Koyeb es Render free, pero **duerme a los 15
minutos de inactividad** y el arranque en frío tarda ~50 s — mala experiencia para una
evaluación.

### Opción C — Azure for Students (mejor opción gratuita si calificas)

| Pieza | Servicio | Costo |
|---|---|---|
| API | App Service F1 | gratis |
| Base de datos | Azure Database for MySQL Flexible B1ms | gratis 12 meses |
| Imágenes | Azure Blob Storage | **ya soportado en el código** |
| Frontend | Netlify o Static Web Apps | gratis |

**Por qué:** `StorageService` ya está implementado contra Azure Blob — solo hay que poner
credenciales reales. Da $100 de crédito sin tarjeta de crédito.

**Contra:** requiere correo institucional válido, y el beneficio expira.

### Recomendación

**Opción A si puedes gastar $5/mes** — llegas a una app funcional en una tarde y sin
escribir código de infraestructura. **Opción C si tienes correo institucional** — mismo
resultado, gratis, a cambio de configurar Azure. La Opción B déjala como plan de respaldo:
funciona, pero pagas la diferencia en tiempo de integración.

---

## 4. Plan de ejecución por fases

### Fase 0 — Seguridad (hacer primero, bloquea todo lo demás)

1. Vaciar los valores sensibles de `appsettings.json` dejando solo la estructura.
2. Rotar la contraseña de MySQL en el proveedor.
3. Generar una clave JWT nueva de 32+ caracteres.
4. Configurar en el host como variables de entorno:
   - `ConnectionStrings__DefaultConnection`
   - `Jwt__SecretKey`
   - `ASPNETCORE_ENVIRONMENT=Production`
5. Documentar en el README que `appsettings.Development.json` es solo local.

> El doble guion bajo (`__`) es la convención de .NET para anidar secciones en variables de
> entorno. No hace falta tocar `Program.cs`.

### Fase 1 — Desbloquear el acceso de administración

6. Crear `ProductionSeeder` que corra en producción **solo si** existe la variable
   `SEED_STAFF_EMAIL`, y que cree un usuario `staff` con `Status = "approved"` tomando
   correo y contraseña de variables de entorno. Idempotente: si el correo ya existe, no
   hace nada.
7. Invocarlo desde `Program.cs` junto al bloque de migraciones.
8. Tras el primer arranque, borrar las variables del host para que no queden expuestas.

Con esto el flujo queda cerrado: alguien se registra → queda `pending` → el staff entra al
panel y lo aprueba → puede usar la app.

### Fase 2 — Base de datos y despliegue del backend

9. Provisionar la base de datos según la opción elegida.
10. Verificar que las 5 migraciones aplican limpias sobre una base vacía
    (`dotnet ef database update`). Nota: la migración `AddQuickMatchSkills` fue editada a
    mano y `Program.cs` tiene una red de seguridad `EnsureColumnAsync` — probar en base
    vacía **y** sobre la base actual de Railway.
11. Agregar `GET /health` que devuelva `200 OK` sin autenticación.
12. Desplegar el contenedor y confirmar `/health` y `/swagger`.

### Fase 3 — Almacenamiento de imágenes

Según la opción:
- **A:** montar un volumen en `/app/wwwroot/uploads` y forzar `LocalStorageService` también
  en producción. Sin código nuevo.
- **B:** implementar `CloudinaryStorageService : IStorageService` y registrarlo en
  `DependencyInjection`.
- **C:** rellenar `AzureBlob:ConnectionString` y `CdnBaseUrl` con valores reales.

### Fase 4 — Conectar el frontend

13. Agregar el dominio de Netlify a la lista de CORS en `Program.cs`.
14. Corregir `social_hub_service.dart` para leer `HUB_URL` desde `fromEnvironment` en vez de
    `localhost:5001`.
15. Actualizar los `defaultValue` de `api_client.dart` y `chat_hub_service.dart` a la URL
    nueva.
16. Compilar sin modo demo:

```bash
flutter build web --release --dart-define=API_URL=https://TU-API/api --dart-define=HUB_URL=https://TU-API/hubs/chat
```

17. Publicar en Netlify y verificar el recorrido completo: registro → aprobación por staff →
    login → publicar → comentar → dar like → recargar y comprobar que **todo persiste**.

### Fase 5 — Completar el registro de interacciones (I1)

18. Escribir en `UserActivity` desde los handlers que hoy no lo hacen:
    `LoginCommandHandler`, `ToggleLikeCommandHandler`, `AddCommentCommandHandler`,
    `FollowUserCommandHandler`, `ApplyToJobCommandHandler`, `UpdateProfileCommandHandler`.
19. Con eso el CV automático y el reporte de usuario pasan a tener contenido real.

> Conviene resolverlo con un `IActivityLogger` inyectado, o con un behavior de MediatR, para
> no repetir el mismo bloque en seis handlers.

### Fase 6 — Endurecimiento (posterior)

20. Respaldos periódicos de la base de datos.
21. Verificación de correo en el registro.
22. Refresh tokens con revocación.

---

## 5. Orden sugerido y esfuerzo

| Fase | Bloquea | Esfuerzo |
|---|---|---|
| 0 — Secretos | todo | bajo |
| 1 — Seeder de staff | el uso real de la app | bajo |
| 2 — BD y despliegue | el frontend | medio |
| 3 — Imágenes | perfiles y publicaciones con foto | bajo–medio |
| 4 — Frontend | — | bajo |
| 5 — Interacciones | CV y reportes | medio |
| 6 — Endurecimiento | — | posterior |

Las fases 0 a 4 son el mínimo para tener una aplicación funcional y usable. La fase 5 es lo
que hace que las funciones de CV y reportes dejen de estar vacías.

---

## 6. Qué NO hay que hacer

- **No borrar el modo demo.** `DEMO_MODE`, `demo_backend.dart` y `demo_interceptor.dart`
  quedan como están; son un flag de compilación y sirven para el próximo estudio.
- **No hacer público el repositorio** hasta completar la Fase 0. Hoy expondría la
  contraseña de la base de datos y la clave JWT.
- **No rehacer el backend.** El modelo de datos, la autenticación y los endpoints ya están
  completos; el trabajo pendiente es de despliegue y configuración.
