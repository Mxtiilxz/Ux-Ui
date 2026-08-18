# Producción

Kairos está **desplegado y funcionando**. Este documento describe cómo está montado, cómo
entrar, cómo volver a desplegarlo y qué queda pendiente.

| Pieza | Dónde | Estado |
|---|---|---|
| Aplicación | [kairoswebapp.netlify.app](https://kairoswebapp.netlify.app) | En línea |
| API | [ux-ui-b1s1.onrender.com](https://ux-ui-b1s1.onrender.com/health) | En línea — `GET /health` responde `{"status":"ok"}` |
| Base de datos | PostgreSQL en Supabase | 8 migraciones aplicadas, 14 tablas |
| Archivos | Supabase Storage, bucket público `kairos-media` | Operativo |
| Demo sin backend | [kairos-legacydemo.netlify.app](https://kairos-legacydemo.netlify.app) | En línea — ver [DEMO.md](DEMO.md) |

> ⏱️ Ambos planes gratuitos se duermen. Render apaga la API tras 15 minutos sin tráfico y
> tarda unos 50 segundos en despertar; la aplicación se adelanta pidiendo `/health` al
> cargar la página, así que para cuando alguien escribe sus credenciales el servidor ya
> responde. Supabase pausa el proyecto tras 7 días de inactividad y hay que reactivarlo a
> mano desde su panel.

---

## 1. Cómo entrar

Las cuentas las crea el liceo: el registro público deja a los alumnos en estado `pending`
hasta que un `staff` los aprueba, y el rol `staff` no se puede pedir desde el formulario.
Por eso una instalación nueva necesita al menos una cuenta sembrada (sección 5).

### Cuentas de muestra

Las crea `EvaluationSeeder` cuando se arranca con `SEED_DEMO_CONTENT=true`. Todas nacen
**aprobadas** y comparten la contraseña que se haya puesto en `SEED_DEMO_PASSWORD`.

| Correo | Rol | Qué tiene |
|---|---|---|
| `contacto@automatizacion.cl` | Empresa | Tres ofertas publicadas, una postulación por revisar, conexión aceptada con Camila |
| `camila.vidal@kairos.cl` | Alumna | Currículum completo (formación y experiencia), competencias, una postulación enviada, una solicitud de conexión por responder |
| `benjamin.soto@kairos.cl` | Alumno | Competencias de mecatrónica, una publicación |
| `valentina.paredes@kairos.cl` | Alumna | Competencias de electricidad, solicitud de conexión pendiente hacia Camila |
| `matias.cortes@kairos.cl` | Alumno | Competencias de mecánica industrial |

Camila es la cuenta más completa: es la que sirve para ver el perfil, el CV descargable y
el estado de una postulación.

La cuenta `staff` es aparte y la crea `ProductionSeeder` con las variables `SEED_STAFF_*`
(sección 5). Ninguna cuenta de muestra es `staff`, a propósito: el panel de gestión no
queda expuesto por sembrar contenido.

---

## 2. Arquitectura del despliegue

Supabase ofrece Postgres, Auth, Storage, Realtime y Edge Functions, pero las Edge Functions
son **Deno/TypeScript únicamente**: no ejecutan contenedores Docker ni el runtime de .NET.
El backend de Kairos son cuatro proyectos de ASP.NET Core, así que Supabase cubre la base de
datos y los archivos, y la API necesita su propio host.

| Host | Situación |
|---|---|
| **Render** | El que se usa. Gratis y sin tarjeta, 750 h/mes. Duerme a los 15 min |
| Koyeb | ❌ Mistral la compró en febrero de 2026 y cerró el plan gratuito a las cuentas nuevas |
| Fly.io | ❌ Eliminó su plan gratuito y exige tarjeta |

---

## 3. Base de datos

### Cadena de conexión

En **Connect → .NET**, Supabase no entrega la cadena suelta: la muestra dentro de un
`appsettings.json` de ejemplo y sugiere instalar `Microsoft.Extensions.Configuration.Json`.
De esos tres pasos solo sirve el valor de `DefaultConnection`:

```
Host=aws-0-REGION.pooler.supabase.com;Port=5432;Database=postgres;Username=postgres.REFERENCIA;Password=TU_PASSWORD;SSL Mode=Require;Trust Server Certificate=true
```

> 🔒 **No copiar el `appsettings.json` que ofrece la consola.** Ese archivo está versionado
> en git, y por eso mismo ya hay una contraseña filtrada en el historial de este
> repositorio. La cadena va como variable de entorno, nunca en un archivo del repo.

Tres detalles que cuestan tiempo si se pasan por alto:

- Supabase **omite `Port=` del string** aunque lo liste aparte en los parámetros de
  conexión. Hay que agregarlo a mano.
- El paquete `Microsoft.Extensions.Configuration.Json` **no hace falta**: ASP.NET Core ya
  lo trae.
- Si la contraseña contiene `;` o `=`, encerrar el valor entre comillas dobles dentro de la
  cadena: `Password="mi;clave"`.

> Usar el **Session pooler** (puerto 5432), no el Transaction pooler (6543): este último no
> admite sentencias preparadas y EF Core las usa.

### Migraciones

Son ocho y la API las aplica sola al arrancar, así que normalmente no hay que hacer nada.
Para aplicarlas a mano —por ejemplo, para comprobar la conexión antes de desplegar:

```bash
cd backend && KAIROS_DESIGN_TIME_CONNECTION="LA_CADENA_DE_ARRIBA" dotnet ef database update --project src/Kairos.Infrastructure --startup-project src/Kairos.API
```

| Migración | Qué agrega |
|---|---|
| `InitPostgres` | Las 11 tablas iniciales |
| `AddPostImageAltText` | Texto alternativo de las imágenes de publicaciones |
| `AddJobPostingSkills` | Competencias que solicita cada oferta — es lo que hace medible la demanda |
| `AddSavedJobs` | Ofertas guardadas, que antes vivían solo en memoria del widget |
| `AddUserApprovedAt` | Fecha de alta real, distinta de la de registro |
| `AddConnectionStatus` | Conexiones bilaterales con solicitud y respuesta |
| `AddPrivacyPreferences` | Quién puede escribirle y quién ve lo que publica cada usuario |
| `AddCvEntries` | Formación y experiencia del currículum |

Para confirmar el esquema, en el **SQL Editor** de Supabase:

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' ORDER BY table_name;
```

Deben aparecer 15 filas: `__EFMigrationsHistory` más las 14 tablas de la aplicación
(`comments`, `cv_entries`, `follows`, `job_applications`, `job_posting_skills`,
`job_postings`, `likes`, `messages`, `posts`, `saved_jobs`, `skills`, `user_activities`,
`user_skills`, `users`).

Para revisar el SQL sin ejecutarlo:

```bash
cd backend && dotnet ef migrations script --idempotent --project src/Kairos.Infrastructure --startup-project src/Kairos.API
```

### Almacenamiento de imágenes

1. En **Storage**, crear un bucket llamado `kairos-media`.
2. Marcarlo como **público**. `SupabaseStorageService` devuelve URLs públicas directas; con
   un bucket privado habría que firmar URLs temporales en cada lectura, lo que obligaría a
   cambiar la interfaz `IStorageService`.
3. En **Project Settings → API**, copiar la **Project URL** y la clave **`service_role`**.

> 🔒 La clave `service_role` salta las políticas de Row Level Security. Va solo en el
> servidor, nunca en la app Flutter.

---

## 4. Desplegar la API en Render

**New → Web Service → Connect a repository.** El repositorio es privado; Render accede por
la app de GitHub sin hacerlo público.

| Campo | Valor | Por qué |
|---|---|---|
| Branch | la rama que se quiera publicar | Render redespliega en cada push a esa rama |
| Language | `Docker` | Se detecta solo al ver el Dockerfile |
| Root Directory | `backend` | El Dockerfile hace `COPY Kairos.sln .` y ese archivo vive en `backend/`, no en la raíz. Con la raíz por defecto la build falla en la primera instrucción |
| Dockerfile Path | `./Dockerfile` | Relativo al Root Directory |
| Instance Type | `Free` | 750 h/mes, sin tarjeta |
| Health Check Path | `/health` | No toca la base de datos, así que un problema de BD no provoca reinicios en bucle |

### Variables de entorno

| Variable | Valor |
|---|---|
| `ConnectionStrings__DefaultConnection` | La cadena de la sección 3 |
| `Jwt__SecretKey` | Clave de 32+ caracteres — `openssl rand -base64 48` |
| `Supabase__Url` | Project URL, ej. `https://abcdefgh.supabase.co` |
| `Supabase__ServiceKey` | Clave `service_role` |
| `Supabase__Bucket` | `kairos-media` |
| `ASPNETCORE_ENVIRONMENT` | `Production` |
| `PORT` | `8080` |

Render enruta al puerto que indique `PORT` (por defecto 10000), y el Dockerfile fija
`ASPNETCORE_URLS=http://+:8080`. Sin esa variable el servicio arranca pero queda
inalcanzable, que es el fallo más difícil de diagnosticar de toda esta configuración.

Verificar: `https://TU-API.onrender.com/health` debe devolver `{"status":"ok"}`.

---

## 5. Sembrar una instalación nueva

Ambos seeders son idempotentes y no hacen nada salvo que se les entreguen sus variables,
así que es seguro dejarlos en el arranque de forma permanente.

### 5.1 Cuenta de administración — obligatorio

Sin al menos un `staff` la plataforma queda bloqueada: todo registro nace en estado
`pending` y solo un `staff` puede aprobarlo.

| Variable | Ejemplo |
|---|---|
| `SEED_STAFF_EMAIL` | `admin@kairos.cl` |
| `SEED_STAFF_PASSWORD` | una contraseña fuerte |
| `SEED_STAFF_NAME` | `Administración Liceo` |

`ProductionSeeder` crea la cuenta ya aprobada y siembra el catálogo de competencias, que
Quick Match necesita para funcionar. Si el correo ya existe no hace nada. Si no se definen
las variables y no existe ningún staff, la API arranca igual pero deja una advertencia en
el log.

**Después del primer arranque, borrar las tres variables del host.**

### 5.2 Contenido de muestra — opcional

Una base recién creada está vacía: no hay feed, no hay ofertas y Quick Match no devuelve
candidatos. Para una demostración o una revisión externa eso se lee como una aplicación
rota, aunque funcione.

| Variable | Valor |
|---|---|
| `SEED_DEMO_CONTENT` | `true` |
| `SEED_DEMO_PASSWORD` | la contraseña con la que se entrará a todas las cuentas de muestra |

`EvaluationSeeder` crea una empresa, cuatro alumnos con competencias distintas, tres ofertas
atadas al catálogo de Quick Match, cinco publicaciones, un currículum completo, una
postulación y conexiones en ambos estados. Los correos están en la sección 1.

No lleva contraseñas escritas en el código ni crea cuentas `staff`. Reconoce el correo de la
empresa para no sembrar dos veces. **Quitar ambas variables después del primer arranque.**

---

## 6. Compilar y publicar el frontend

```bash
cd frontend
flutter build web --release --dart-define=BACKEND_URL=https://TU-API
```

Un solo indicador basta: `config.dart` deriva de él la URL de la API y las de ambos hubs.
`API_URL`, `HUB_URL` y `SOCIAL_HUB_URL` siguen existiendo para sobrescribirlas por separado.

Para publicar, arrastrar `build/web` al sitio en Netlify, o bien:

```bash
netlify deploy --prod --dir=build/web
```

`frontend/web/` contiene dos archivos que Flutter copia a cada build y que **tienen que
viajar dentro de la carpeta publicada**:

- `_redirects` — sin él, recargar la página en cualquier ruta devuelve el 404 de Netlify en
  vez de la aplicación.
- `netlify.toml` — cabeceras de seguridad (CSP, `X-Frame-Options`, `nosniff`,
  `Referrer-Policy`, `Permissions-Policy`) que por defecto no se envían. Vive en
  `frontend/web/` y no en la raíz del repositorio precisamente porque un despliegue por
  arrastre solo ve lo que está dentro de la carpeta.

> Si se cambia el dominio de la API, hay que actualizar `connect-src` en el `netlify.toml` y
> la lista de orígenes de CORS en `Program.cs`. Si no, el navegador bloquea las peticiones.

### Comprobar que los datos persisten de verdad

Recargar la página después de cada bloque: si algo se pierde al recargar, no se guardó en
Postgres.

1. **Registro y aprobación** — registrar una cuenta de estudiante, entrar con el staff,
   aprobarla, y luego iniciar sesión con ella.
2. **Publicación con imagen** — publicar con una imagen y escribir su descripción en el
   campo "Describe la imagen". Confirmar en Supabase:

   ```sql
   SELECT "Id", "ImageUrl", "ImageAltText" FROM posts ORDER BY "CreatedAt" DESC LIMIT 5;
   ```

   `ImageUrl` debe apuntar a `.../storage/v1/object/public/kairos-media/...` y abrir en el
   navegador. `ImageAltText` debe traer lo que se escribió, o `NULL` si se dejó vacío, que
   es lo correcto para una imagen decorativa.
3. **Interacciones** — dar me gusta, comentar, solicitar una conexión y postular a una
   oferta. Recargar y verificar que los contadores se mantienen.
4. **Quick Match** — como empresa, filtrar por competencias y contactar a un candidato.
   Comprobar que el mensaje aparece del lado correcto de la conversación.
5. **Tiempo real** — con dos navegadores y dos cuentas: dar me gusta a una publicación de la
   otra cuenta. En la ventana del autor debe aparecer el aviso en la barra superior. Si no
   aparece, revisar que el WebSocket a `/hubs/social` no esté bloqueado por el host.
6. **Sesión** — cerrar el navegador, volver a abrir la app y comprobar que sigue iniciada.

---

## 7. Qué está verificado y qué no

Verificado en el repositorio (17 de agosto de 2026):

| Comprobación | Resultado |
|---|---|
| `dotnet build` de la solución | 0 advertencias, 0 errores |
| `dotnet test` | 5 de 5 — traducción a SQL de las consultas del feed y de la red |
| `flutter analyze` | **Sin ningún aviso**, ni siquiera de nivel `info` |
| `flutter test` | 35 de 35 |
| `flutter build web --release` (producción y demo) | Ambas compilan |
| `dotnet ef migrations script --idempotent` | SQL de PostgreSQL válido |

Verificado contra la infraestructura real, recorriendo la aplicación publicada:

| Comprobación | Resultado |
|---|---|
| `dotnet ef database update` contra Supabase | Migraciones aplicadas sin error |
| `GET /health` en Render | `200 {"status":"ok"}` |
| Endpoints sin token (`/posts/feed`, `/jobs`, `/skills`, `/stats/community`) | `401` en los cuatro — ninguno filtra datos |
| Formato de los errores de la API | `application/problem+json` (RFC 7807) |
| Consola del navegador en producción | Sin errores; las 7 peticiones de carga responden `200` |
| CORS Netlify → Render | Preflight `204` con `access-control-allow-origin` correcto |
| `ProductionSeeder` | Cuenta staff creada y con sesión iniciada |
| Registro, aprobación y login de un alumno | Persisten tras cerrar sesión y recargar |
| Subida de imágenes a Supabase Storage | La imagen de una publicación se muestra tras publicarla |
| Notificaciones en vivo (SignalR) | El "me gusta" de una sesión llega a la otra |
| Reflujo al 200 % de zoom | Sin pérdida de contenido |

**Sin verificar todavía:**

- La generación del CV en PDF y del reporte mensual contra el contenedor de producción.
  QuestPDF necesita las librerías nativas de SkiaSharp, que el `Dockerfile` instala, pero
  eso no se ha ejercitado.
- La certificación manual de accesibilidad con lectores de pantalla reales (NVDA,
  VoiceOver, TalkBack), detallada en
  [`docs/accessibility/`](docs/accessibility/WCAG_2_2_AA_IMPLEMENTATION_2026-08-11.md). Los
  tests automatizados cubren el árbol de semántica, el contraste y la navegación por
  teclado, que es otra cosa.

---

## 8. Pendientes conocidos

### El reporte mensual sale casi vacío

`UserActivity` es la bitácora de uso, y **solo `CreatePostCommandHandler` escribe en ella**.
Logins, me gusta, comentarios, conexiones y postulaciones no registran nada, así que el
reporte mensual del panel de staff (`GetUserReportQueryHandler`) refleja una fracción de lo
que ocurre.

Falta escribir actividad desde `LoginCommandHandler`, `ToggleLikeCommandHandler`,
`AddCommentCommandHandler`, `FollowUserCommandHandler`, `ApplyToJobCommandHandler` y
`UpdateProfileCommandHandler`. Conviene resolverlo con un `IActivityLogger` inyectado o un
behavior de MediatR, en vez de repetir el mismo bloque en seis handlers.

> Esto **ya no afecta al CV**. El currículum se armaba desde esta misma bitácora, que es la
> razón por la que salía listando likes y comentarios; ahora se construye desde el perfil y
> la tabla `cv_entries`, así que es independiente del registro de actividad.

### La pantalla de chat no tiene test de widgets

`ChatsPage` no llega a un estado quieto bajo `pumpAndSettle`, pero **no es un defecto de la
aplicación**: en un test sin backend la pantalla se queda en su indicador de carga, y un
`CircularProgressIndicator` es una animación indeterminada que por definición nunca termina.
`pumpAndSettle` espera a que todas las animaciones acaben, así que agota su tiempo. Los dos
temporizadores de la pantalla se cancelan en `dispose()`; no hay ninguna fuga.

Lo que falta es el test, que sí se puede escribir: hay que avanzar el reloj con
`pump(Duration)` en vez de `pumpAndSettle`, y compilar con `--dart-define=DEMO_MODE=true`
para que el backend simulado responda. La atribución de cada mensaje —quién lo envió, de
qué lado aparece— está cubierta hoy a nivel de datos en
[`demo_chat_sides_test.dart`](frontend/test/demo_chat_sides_test.dart).

---

## 9. Advertencias de seguridad

**No hacer público el repositorio** sin antes reescribir el historial o rotar todo. La
contraseña de la base de datos de Railway y la clave JWT antigua estuvieron versionadas en
`appsettings.json`; siguen en el historial de git aunque ya no estén en la copia de trabajo.
La clave JWT en uso es nueva y vive solo como variable de entorno. La base de MySQL de
Railway conviene eliminarla si no se ha hecho.

**Los seeders son puertas.** `SEED_STAFF_PASSWORD` y `SEED_DEMO_PASSWORD` crean cuentas con
contraseñas conocidas. Quitar las variables del host una vez sembrado, y cambiar esas
contraseñas si la instalación va a quedar en uso real.

**Límites del plan gratuito de Supabase:** 500 MB de base de datos, 1 GB de archivos, 2
proyectos.
