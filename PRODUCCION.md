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
| Almacenamiento de archivos en Supabase Storage | `Services/SupabaseStorageService.cs` |
| Secretos fuera de `appsettings.json` | `appsettings.json`, `Program.cs` |
| Seeder del primer usuario `staff` | `Persistence/ProductionSeeder.cs` |
| Endpoint `GET /health` sin autenticación | `Program.cs` |
| CORS incluye el dominio de Netlify en uso | `Program.cs` |
| URLs de API y hubs derivadas de un solo indicador | `frontend/lib/core/config.dart` |

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
| **Koyeb** | 1 servicio gratis, no duerme. Recomendado. |
| Render | Gratis, pero duerme a los 15 min y el arranque en frío tarda ~50 s |
| Fly.io | Docker nativo, requiere tarjeta aunque no cobre |

---

## 3. Configurar Supabase

### 3.1 Base de datos

1. Crear un proyecto en [supabase.com](https://supabase.com). Anotar la contraseña de la
   base de datos que se define al crearlo — no se puede volver a ver.
2. En **Project Settings → Database → Connection string**, copiar la cadena en formato
   **.NET / ADO**. Queda parecida a:

   ```
   Host=aws-0-us-east-1.pooler.supabase.com;Port=5432;Database=postgres;Username=postgres.abcdefgh;Password=TU_PASSWORD;SSL Mode=Require;Trust Server Certificate=true
   ```

   > Usar el **Session pooler** (puerto 5432), no el Transaction pooler (6543): este último
   > no admite sentencias preparadas y EF Core las usa.

3. Aplicar la migración desde tu equipo:

```bash
cd backend
KAIROS_DESIGN_TIME_CONNECTION="LA_CADENA_DE_ARRIBA" dotnet ef database update --project src/Kairos.Infrastructure --startup-project src/Kairos.API
```

   La API también aplica las migraciones sola al arrancar, así que este paso es opcional;
   sirve para confirmar que la conexión funciona antes de desplegar.

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

### Desplegar en Koyeb

1. Conectar el repositorio de GitHub.
2. Koyeb detecta `backend/Dockerfile`.
3. Puerto: `8080` (el que expone el Dockerfile).
4. Health check: `GET /health`.
5. Cargar las variables de entorno.

Verificar: `https://TU-API/health` debe devolver `{"status":"ok"}`.

---

## 5. Compilar y publicar el frontend

```bash
cd frontend
flutter build web --release --dart-define=BACKEND_URL=https://TU-API
netlify deploy --prod --dir=build/web
```

Un solo indicador basta: `config.dart` deriva de él la URL de la API y las de ambos hubs.
`API_URL`, `HUB_URL` y `SOCIAL_HUB_URL` siguen existiendo para sobrescribirlas por separado.

Luego, verificar el recorrido completo: registro → aprobación por el staff → login →
publicar → comentar → dar me gusta → **recargar y comprobar que todo persiste**.

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

## 8. Verificación pendiente

La migración genera SQL válido y la solución compila sin advertencias, pero **no se pudo
aplicar contra un Postgres real** en el entorno donde se hicieron estos cambios (no había
Docker ni una instancia local). El primer `dotnet ef database update` contra Supabase es el
que confirma que el esquema se crea completo.

Igualmente sin verificar por depender de credenciales: la subida de archivos a Supabase
Storage y el arranque de `ProductionSeeder`.
