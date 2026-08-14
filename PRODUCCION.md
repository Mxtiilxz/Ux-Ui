# Paso a producción con Supabase

El código ya está migrado a PostgreSQL y a Supabase Storage. Este documento explica qué se
cambió, qué queda por hacer en las consolas web y cómo desplegar.

---

## 1. Estado

### Ya implementado en el repositorio

| Cambio | Dónde |
|---|---|
| Proveedor EF Core: MySQL → PostgreSQL | `Kairos.Infrastructure.csproj`, `DependencyInjection.cs`, `ApplicationDbContextFactory.cs` |
| Migración inicial nativa de Postgres (11 tablas) | `Migrations/*_InitPostgres.cs` |
| Texto alternativo de las imágenes de publicaciones | `Migrations/*_AddPostImageAltText.cs` |
| Almacenamiento de archivos en Supabase Storage | `Services/SupabaseStorageService.cs` |
| Secretos fuera de `appsettings.json` | `appsettings.json`, `Program.cs` |
| Seeder del primer usuario `staff` | `Persistence/ProductionSeeder.cs` |
| Endpoint `GET /health` sin autenticación | `Program.cs` |
| CORS incluye el dominio de Netlify en uso | `Program.cs` |
| URLs de API y hubs derivadas de un solo indicador | `frontend/lib/core/config.dart` |
| Notificaciones sociales en vivo conectadas de punta a punta | `frontend/lib/main.dart`, `SocialHub.cs` |

### Pendiente

| Tarea | Por qué |
|---|---|
| Crear el proyecto en Supabase y aplicar la migración | Requiere tu cuenta |
| Desplegar la API en un host | Supabase no ejecuta contenedores .NET |
| Rotar la clave JWT y la contraseña de MySQL antigua | Estuvieron en git; siguen comprometidas |
| Completar el registro de interacciones | El CV y el reporte salen casi vacíos — sección 6 |

---

## 2. Por qué Supabase no aloja la API

Supabase ofrece Postgres, Auth, Storage, Realtime y Edge Functions. Las Edge Functions son
**Deno/TypeScript únicamente**: no ejecutan contenedores Docker ni el runtime de .NET.

El backend de Kairos son cuatro proyectos de ASP.NET Core, así que Supabase cubre la base de
datos y los archivos, pero la API necesita su propio host. Opciones gratuitas:

| Host | Nota |
|---|---|
| **Render** | Gratis y sin tarjeta, 750 h/mes. Duerme a los 15 min sin tráfico y el arranque en frío tarda 30–60 s. **Recomendado**: es el único de los tres con plan gratuito real hoy |
| Koyeb | ❌ Ya no sirve. Mistral la compró en febrero de 2026 y **cerró el plan gratuito a las cuentas nuevas**; las existentes lo conservan |
| Fly.io | ❌ Eliminó su plan gratuito y exige tarjeta |

> Ojo con la suma de dos capas que se duermen: Render se apaga a los 15 minutos y Supabase
> pausa el proyecto tras 7 días. El primer acceso después de un fin de semana puede tardar
> un minuto largo, y tras una semana entera hay que despausar Supabase a mano antes.

---

## 3. Configurar Supabase

De principio a fin son seis pasos. Los tres primeros se hacen en la consola de Supabase, el
cuarto desde tu equipo, y los dos últimos en el host de la API:

1. Crear el proyecto y guardar la contraseña de la base de datos (3.1).
2. Copiar la cadena de conexión en formato **.NET**, con el **Session pooler** (3.1).
3. Crear el bucket público `kairos-media` y copiar la Project URL y la clave
   `service_role` (3.2).
4. Aplicar las migraciones y comprobar que aparecen las 12 tablas (3.1, pasos 3 y 4).
5. Cargar las variables de entorno en el host de la API (sección 4).
6. Arrancar una vez con las variables `SEED_STAFF_*` para crear la cuenta de
   administración, y borrarlas después (sección 4).

### 3.1 Base de datos

1. Crear un proyecto en [supabase.com](https://supabase.com). Anotar la contraseña de la
   base de datos que se define al crearlo — no se puede volver a ver.
2. En **Connect → .NET**, Supabase no entrega la cadena suelta: la muestra dentro de un
   `appsettings.json` de ejemplo y sugiere instalar
   `Microsoft.Extensions.Configuration.Json`. De esos tres pasos, aquí solo sirve el valor
   de `DefaultConnection`:

   ```
   Host=aws-0-REGION.pooler.supabase.com;Port=5432;Database=postgres;Username=postgres.REFERENCIA;Password=TU_PASSWORD;SSL Mode=Require;Trust Server Certificate=true
   ```

   > 🔒 **No copiar el `appsettings.json` que ofrece la consola.** Ese archivo está
   > versionado en git y por eso mismo ya hay una contraseña filtrada en el historial de
   > este repositorio. La cadena va como variable de entorno, nunca en un archivo del repo.

   Tres detalles de la cadena:

   - Supabase **omite `Port=` del string** aunque lo liste aparte en los parámetros de
     conexión. Agregarlo a mano.
   - El paquete `Microsoft.Extensions.Configuration.Json` **no hace falta**: ASP.NET Core
     ya lo trae.
   - Si la contraseña contiene `;` o `=`, encerrar el valor entre comillas dobles dentro de
     la cadena: `Password="mi;clave"`.

   > Usar el **Session pooler** (puerto 5432), no el Transaction pooler (6543): este último
   > no admite sentencias preparadas y EF Core las usa.

3. Aplicar las migraciones desde tu equipo. Son dos: la inicial crea las 11 tablas y la
   segunda agrega la columna del texto alternativo de las imágenes.

```bash
cd backend && KAIROS_DESIGN_TIME_CONNECTION="LA_CADENA_DE_ARRIBA" dotnet ef database update --project src/Kairos.Infrastructure --startup-project src/Kairos.API
```

   La API también aplica las migraciones sola al arrancar, así que este paso es opcional;
   sirve para confirmar que la conexión funciona antes de desplegar.

4. Confirmar que el esquema quedó bien. En el **SQL Editor** de Supabase:

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' ORDER BY table_name;
```

   Deben aparecer 12 filas: `__EFMigrationsHistory` más las 11 tablas de la aplicación
   (`comments`, `follows`, `job_applications`, `job_postings`, `likes`, `messages`, `posts`,
   `skills`, `user_activities`, `user_skills`, `users`).

   Si prefieres revisar el SQL antes de tocar la base, esto lo imprime sin ejecutarlo:

```bash
cd backend && dotnet ef migrations script --idempotent --project src/Kairos.Infrastructure --startup-project src/Kairos.API
```

### 3.2 Almacenamiento de imágenes

1. En **Storage**, crear un bucket llamado `kairos-media`.
2. Marcarlo como **público**. `SupabaseStorageService` devuelve URLs públicas directas; con
   un bucket privado habría que firmar URLs temporales en cada lectura, lo que obligaría a
   cambiar la interfaz `IStorageService`.
3. En **Project Settings → API**, copiar la **Project URL** y la clave **`service_role`**.

> 🔒 La clave `service_role` salta las políticas de Row Level Security. Va solo en el
> servidor, nunca en la app Flutter.

---

## 4. Desplegar la API

### Variables de entorno

| Variable | Valor |
|---|---|
| `ConnectionStrings__DefaultConnection` | La cadena del paso 3.1 |
| `Jwt__SecretKey` | Clave nueva de 32+ caracteres |
| `Supabase__Url` | Project URL, ej. `https://abcdefgh.supabase.co` |
| `Supabase__ServiceKey` | Clave `service_role` |
| `Supabase__Bucket` | `kairos-media` |
| `ASPNETCORE_ENVIRONMENT` | `Production` |

Generar la clave JWT:

```bash
openssl rand -base64 48
```

### Primer arranque: crear el usuario staff

Sin al menos un `staff` la plataforma queda bloqueada, porque todo registro nace en estado
`pending` y solo un `staff` puede aprobarlo.

Agregar temporalmente estas tres variables:

| Variable | Ejemplo |
|---|---|
| `SEED_STAFF_EMAIL` | `admin@kairos.cl` |
| `SEED_STAFF_PASSWORD` | una contraseña fuerte |
| `SEED_STAFF_NAME` | `Administración Liceo` |

Al arrancar, `ProductionSeeder` crea la cuenta ya aprobada. Es idempotente: si el correo ya
existe no hace nada. **Después del primer arranque, borrar las tres variables del host.**

Si no se definen y no existe ningún staff, la API arranca igual pero deja una advertencia
en el log.

### Desplegar en Render

**New → Web Service → Connect a repository.** El repositorio es privado; Render accede por
la app de GitHub sin hacerlo público.

| Campo | Valor | Por qué |
|---|---|---|
| Branch | la rama que quieras publicar | Render redespliega en cada push a esa rama |
| Language | `Docker` | Se detecta solo al ver el Dockerfile |
| Root Directory | `backend` | El Dockerfile hace `COPY Kairos.sln .` y ese archivo vive en `backend/`, no en la raíz. Con la raíz por defecto la build falla en la primera instrucción |
| Dockerfile Path | `./Dockerfile` | Relativo al Root Directory |
| Instance Type | `Free` | 750 h/mes, sin tarjeta |
| Health Check Path | `/health` | No toca la base de datos, así que un problema de BD no provoca reinicios en bucle |

A las variables de entorno de la tabla anterior hay que sumarle una más, propia de Render:

| Variable | Valor |
|---|---|
| `PORT` | `8080` |

Render enruta al puerto que indique `PORT` (por defecto 10000), y el Dockerfile fija
`ASPNETCORE_URLS=http://+:8080`. Sin esa variable el servicio arranca pero queda
inalcanzable, que es el fallo más difícil de diagnosticar de toda esta configuración.

Verificar: `https://TU-API.onrender.com/health` debe devolver `{"status":"ok"}`.

---

## 5. Compilar y publicar el frontend

```bash
cd frontend
flutter build web --release --dart-define=BACKEND_URL=https://TU-API
netlify deploy --prod --dir=build/web
```

Un solo indicador basta: `config.dart` deriva de él la URL de la API y las de ambos hubs.
`API_URL`, `HUB_URL` y `SOCIAL_HUB_URL` siguen existiendo para sobrescribirlas por separado.

### Comprobar que los datos persisten de verdad

Este es el recorrido que confirma que la base está bien integrada. Recargar la página
después de cada bloque: si algo se pierde al recargar, no se guardó en Postgres.

1. **Registro y aprobación** — registrar una cuenta de estudiante, entrar con el staff
   creado por `ProductionSeeder`, aprobarla, y luego iniciar sesión con ella.
2. **Publicación con imagen** — publicar con una imagen y escribir su descripción en el
   campo "Describe la imagen". Confirmar en Supabase:

   ```sql
   SELECT "Id", "ImageUrl", "ImageAltText" FROM posts ORDER BY "CreatedAt" DESC LIMIT 5;
   ```

   `ImageUrl` debe apuntar a `.../storage/v1/object/public/kairos-media/...` y abrir en el
   navegador. `ImageAltText` debe traer lo que escribiste (o `NULL` si lo dejaste vacío,
   que es lo correcto para una imagen decorativa).
3. **Interacciones** — dar me gusta, comentar, seguir a alguien y postular a una oferta.
   Recargar y verificar que los contadores se mantienen.
4. **Tiempo real** — con dos navegadores y dos cuentas: dar me gusta a una publicación de
   la otra cuenta. En la ventana del autor debe aparecer el aviso en la barra superior.
   Si no aparece, revisar que el WebSocket a `/hubs/social` no esté bloqueado por el host.
5. **Sesión** — cerrar el navegador, volver a abrir la app y comprobar que la sesión sigue
   iniciada.

---

## 6. Pendiente: completar el registro de interacciones

`UserActivity` alimenta el CV en PDF y el reporte mensual, pero **solo
`CreatePostCommandHandler` escribe en ella**. Logins, likes, comentarios, seguimientos y
postulaciones no registran nada, así que ambos documentos salen casi vacíos.

Falta escribir actividad desde: `LoginCommandHandler`, `ToggleLikeCommandHandler`,
`AddCommentCommandHandler`, `FollowUserCommandHandler`, `ApplyToJobCommandHandler` y
`UpdateProfileCommandHandler`.

Conviene resolverlo con un `IActivityLogger` inyectado o un behavior de MediatR, en vez de
repetir el mismo bloque en seis handlers.

---

## 7. Advertencias

**Rotar los secretos comprometidos.** La contraseña de la base de datos de Railway y la
clave JWT antigua estuvieron versionadas en `appsettings.json`. Siguen en el historial de
git aunque ya no estén en la copia de trabajo. La clave JWT nueva resuelve el lado de la
API; la base de MySQL de Railway conviene eliminarla.

**No hacer público el repositorio** sin antes reescribir el historial o rotar todo.

**Supabase pausa los proyectos gratuitos tras 7 días de inactividad.** Hay que despausarlos
a mano desde el panel. Para un proyecto que se usa a ratos esto muerde: alguien entra un
lunes y la app no responde. `DependencyInjection` reintenta la conexión hasta 3 veces para
absorber el tiempo de despertar, pero no puede despausar el proyecto.

**Límites del plan gratuito:** 500 MB de base de datos, 1 GB de archivos, 2 proyectos.

---

## 8. Qué está verificado y qué no

Verificado en el repositorio:

| Comprobación | Resultado |
|---|---|
| `dotnet build` de la solución | 0 advertencias, 0 errores |
| `dotnet ef migrations script --idempotent` | SQL de PostgreSQL válido, 11 `CREATE TABLE` + la columna nueva |
| `flutter test` | 23 de 23 |
| `flutter analyze --no-fatal-infos` | Sin errores ni advertencias |
| `flutter build web --release` (producción y demo) | Ambas compilan |

Verificado contra la base real:

| Comprobación | Resultado |
|---|---|
| `dotnet ef database update` contra Supabase | Las dos migraciones aplicadas sin error |

**Sin verificar, porque depende de tus credenciales:**

- La subida de archivos a Supabase Storage.
- El arranque de `ProductionSeeder`.
- Las notificaciones en vivo por WebSocket contra un host real.

La sección 5 tiene el recorrido exacto para comprobar los cuatro puntos cuando el proyecto
esté creado.
