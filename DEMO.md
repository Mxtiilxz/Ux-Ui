# Kairos — versión de demostración para pruebas de uso

Build estática pensada para un estudio de usabilidad con Google Analytics.
Funciona **sin backend ni base de datos**: todos los datos viven en memoria
durante la sesión del navegador.

---

## 1. Configurar Google Analytics

**Ya está configurado.** El sitio publicado en
[kairos-legacydemo.netlify.app](https://kairos-legacydemo.netlify.app) mide contra la
propiedad "Kairos" con el ID `G-XDGCXT8NRL`, definido en `web/index.html`:

```js
var KAIROS_GA_ID = 'G-XDGCXT8NRL';
```

Para apuntar a otra propiedad basta con cambiar esa constante. Mientras el valor
contenga `XXXX`, el seguimiento queda desactivado y la app funciona igual — útil
para probar sin ensuciar las estadísticas.

> Puedes editar el archivo directamente en `build/web/index.html` tras compilar —
> no hace falta recompilar para cambiar el ID.

> **Nota metodológica:** los bloqueadores de rastreo y las VPN impiden que el
> evento llegue a `google-analytics.com`. Los eventos se disparan igual y se ven
> en consola, pero no se registran. Conviene mencionarlo como limitación del
> estudio: suele afectar a entre un 10 % y un 30 % de los visitantes.

---

## 2. Publicar el sitio

### Netlify (gratis, sin instalar nada)

1. Entra a [app.netlify.com](https://app.netlify.com) con tu cuenta.
2. Abre el sitio de la demo (`kairos-legacydemo`) → pestaña **Deploys**.
3. Arrastra la carpeta `frontend/build/web` completa sobre la zona de
   "Drag and drop your site output folder here".

Al desplegar sobre el sitio existente, la URL no cambia y Analytics sigue
midiendo sin reconfigurar nada.

> ⚠️ **No confundir los dos sitios.** `kairoswebapp` es la aplicación real, conectada
> a la base de datos; `kairos-legacydemo` es esta demo en memoria. Subir aquí una build
> de producción, o al revés, es fácil de hacer y difícil de notar: ambas se ven igual
> hasta que alguien intenta iniciar sesión. La demo se compila **siempre** con
> `--dart-define=DEMO_MODE=true`.

### Alternativa: servirlo desde un computador

Si prefieres levantarlo en un equipo que quede encendido:

```bash
cd frontend/build/web
python3 -m http.server 8080
```

Queda disponible en `http://localhost:8080`. Para exponerlo a internet se
necesita además un túnel (por ejemplo Cloudflare Tunnel).

---

## 3. Cómo entran los testers

No necesitan cuenta ni contraseña. En la pantalla de inicio eligen con qué
perfil quieren recorrer la plataforma:

| Perfil | Qué puede hacer |
|---|---|
| **Estudiante** | Ver el feed, dar me gusta, comentar, publicar, registrar sus competencias, activar su visibilidad en Quick Match, postular a ofertas y descargar su CV. |
| **Empresa** | Publicar ofertas, revisar postulantes y usar **Quick Match** para buscar estudiantes por competencias y contactarlos por chat. |

El perfil de **staff / administración del liceo no está disponible** a
propósito: los testers no deben acceder al panel de gestión de usuarios.

**Importante para los testers:** lo que hagan se mantiene durante la sesión,
pero se reinicia al recargar la página. Es una demostración funcional, no un
entorno con datos persistentes.

---

## 4. Qué se mide en Analytics

Todos los eventos se registran con nombres en español para que el informe sea
legible directamente en GA (Informes → Interacción → Eventos).

| Evento | Cuándo se dispara | Parámetros |
|---|---|---|
| `login` | El tester entra eligiendo un perfil | `rol` |
| `logout` | Cierra sesión | — |
| `ver_pestana` | Cambia de pestaña | `pestana` |
| `post_like` | Da o quita un me gusta | `accion` |
| `post_publicar` | Publica en el feed | `tipo` (general/evento) |
| `post_comentar` | Comenta una publicación | — |
| `post_compartir` | Usa el botón compartir | — |
| `oferta_postular` | Postula a una oferta | `oferta` |
| `oferta_publicar` | Publica una oferta laboral | — |
| `oferta_ver_postulantes` | Revisa los postulantes | — |
| `quickmatch_filtro` | Marca o desmarca una competencia en la búsqueda | `competencia`, `accion` |
| `quickmatch_buscar` | Ejecuta la búsqueda de candidatos | `competencias_buscadas`, `candidatos_encontrados` |
| `quickmatch_contactar` | Contacta a un candidato | `coincidencia` |
| `quickmatch_mensaje` | Guarda su mensaje de contacto | `accion` (personalizar/restablecer) |
| `competencia_perfil` | Agrega o quita una competencia propia | `competencia`, `accion` |
| `quickmatch_visibilidad` | Activa o desactiva su visibilidad | `visible` |
| `descargar_cv` | Genera y descarga el CV | — |
| `descargar_reporte` | Descarga el reporte mensual | — |
| `red_seguir` | Sigue o deja de seguir a alguien | `accion` |
| `chat_enviar_mensaje` | Envía un mensaje | — |

### Verificar que los eventos llegan

- **En vivo:** GA → Informes → **Tiempo real**. Los eventos aparecen a los
  pocos segundos.
- **En el navegador:** abre la consola y ejecuta
  `window.KAIROS_DEBUG_ANALYTICS = true`. Cada interacción se imprime como
  `[analytics] nombre_evento {...}` aunque GA no esté configurado.

> Los informes estándar de GA pueden tardar hasta 24-48 h en consolidar datos.
> Para revisar durante las pruebas usa **Tiempo real** o **Exploraciones**.

---

## 5. Volver al modo normal (con backend)

El modo demo se activa solo al compilar con el indicador correspondiente. Para
generar la build normal, que habla con un backend real:

```bash
flutter build web --release --dart-define=API_URL=https://TU-BACKEND/api --dart-define=HUB_URL=https://TU-BACKEND/hubs/chat
```

Sin `--dart-define=DEMO_MODE=true` la aplicación usa la API de verdad y el
inicio de sesión vuelve a pedir credenciales.

Para levantar ese backend real, ver [PRODUCCION.md](PRODUCCION.md).

---

## 6. Cómo se compiló esta build

```bash
cd frontend
flutter build web --release --dart-define=DEMO_MODE=true
```

El flag vive en `lib/core/config.dart` como `kDemoMode`. Con él activo,
`demo_interceptor.dart` intercepta cada petición de Dio y la resuelve contra
`demo_backend.dart`, y los servicios SignalR no intentan conectarse. Ninguna
pantalla necesitó modificarse para soportar el modo demo.
