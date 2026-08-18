# Modo demo

Build estática para estudios de usabilidad con Google Analytics. Funciona sin backend ni
base de datos: los datos viven en memoria durante la sesión del navegador y se reinician al
recargar la página.

Publicada en [kairos-legacydemo.netlify.app](https://kairos-legacydemo.netlify.app).

## Compilar y publicar

```bash
cd frontend
flutter build web --release --output=build/demo --dart-define=DEMO_MODE=true
```

La salida va a `build/demo`, separada de `build/web` para que las dos builds no se pisen.
Para publicar, entrar a [app.netlify.com](https://app.netlify.com), abrir el sitio
`kairos-legacydemo`, pestaña **Deploys**, y arrastrar la carpeta `frontend/build/demo`
completa. La URL no cambia y Analytics sigue midiendo sin reconfigurar nada.

No confundir los dos sitios. `kairoswebapp` es la aplicación real, conectada a la base de
datos; `kairos-legacydemo` es esta demo en memoria. Ambas se ven idénticas hasta que
alguien intenta iniciar sesión, así que subir una build al sitio equivocado es fácil de
hacer y difícil de notar. La demo se compila siempre con `DEMO_MODE=true` y sale a
`build/demo`; la de producción, sin ese flag y a `build/web`.

## Cómo entran los participantes

No necesitan cuenta ni contraseña. En la pantalla de inicio eligen con qué perfil recorrer
la plataforma.

| Perfil | Alcance |
|---|---|
| Estudiante | Feed, me gusta, comentarios, publicaciones, competencias propias, visibilidad en Quick Match, postulaciones y descarga del currículum |
| Empresa | Publicar ofertas, revisar postulantes y usar Quick Match para buscar estudiantes por competencias y contactarlos por chat |

El perfil de staff no se ofrece: los participantes no deben llegar al panel de gestión de
usuarios.

## Google Analytics

El sitio mide contra la propiedad "Kairos" con el identificador `G-XDGCXT8NRL`, definido en
`web/index.html`:

```js
var KAIROS_GA_ID = 'G-XDGCXT8NRL';
```

Para apuntar a otra propiedad basta con cambiar esa constante, incluso directamente en
`build/demo/index.html` después de compilar. Mientras el valor contenga `XXXX`, el
seguimiento queda desactivado y la aplicación funciona igual, lo que sirve para hacer
pruebas sin ensuciar las estadísticas.

### Eventos

Los nombres están en español para que el informe se lea directamente en Analytics, en
Informes, Interacción, Eventos.

| Evento | Cuándo se dispara | Parámetros |
|---|---|---|
| `login` | Entra eligiendo un perfil | `rol` |
| `logout` | Cierra sesión | |
| `ver_pestana` | Cambia de pestaña | `pestana` |
| `post_like` | Da o quita un me gusta | `accion` |
| `post_publicar` | Publica en el feed | `tipo` |
| `post_comentar` | Comenta una publicación | |
| `post_compartir` | Usa el botón compartir | |
| `oferta_postular` | Postula a una oferta | `oferta` |
| `oferta_publicar` | Publica una oferta | |
| `oferta_ver_postulantes` | Revisa los postulantes | |
| `quickmatch_filtro` | Marca o desmarca una competencia en la búsqueda | `competencia`, `accion` |
| `quickmatch_buscar` | Ejecuta la búsqueda | `competencias_buscadas`, `candidatos_encontrados` |
| `quickmatch_contactar` | Contacta a un candidato | `coincidencia` |
| `quickmatch_mensaje` | Guarda su plantilla de contacto | `accion` |
| `competencia_perfil` | Agrega o quita una competencia propia | `competencia`, `accion` |
| `quickmatch_visibilidad` | Cambia su visibilidad | `visible` |
| `descargar_cv` | Descarga el currículum | |
| `descargar_reporte` | Descarga el reporte mensual | |
| `red_seguir` | Solicita o deshace una conexión | `accion` |
| `chat_enviar_mensaje` | Envía un mensaje | |

### Comprobar que los eventos llegan

En Analytics, el informe de Tiempo real los muestra a los pocos segundos. En el navegador,
ejecutar `window.KAIROS_DEBUG_ANALYTICS = true` en la consola imprime cada interacción como
`[analytics] nombre_evento {...}`, incluso si Analytics no está configurado.

Los informes estándar tardan entre 24 y 48 horas en consolidar datos, así que durante las
pruebas conviene usar Tiempo real o Exploraciones.

Conviene anotar una limitación metodológica: los bloqueadores de rastreo y las VPN impiden
que el evento llegue a `google-analytics.com`. Se disparan igual y se ven en consola, pero
no quedan registrados. Suele afectar a entre el 10 y el 30 por ciento de los visitantes.

## Cómo funciona

El flag vive en `lib/core/config.dart` como `kDemoMode`. Con él activo,
`demo_interceptor.dart` intercepta cada petición de Dio y la resuelve contra
`demo_backend.dart`, y los servicios SignalR no intentan conectarse. Ninguna pantalla
necesitó modificarse para admitir este modo.

Para volver a la build normal, que habla con un backend real, basta con omitir el flag. El
procedimiento completo está en [PRODUCCION.md](PRODUCCION.md).
