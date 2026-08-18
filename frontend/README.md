# Kairos — Frontend

Aplicación web en Flutter 3 con Material 3. Consume la API de
[`backend/`](../backend/README.md) por HTTP y SignalR.

## Requisitos

Flutter 3 con soporte web habilitado y un navegador Chromium, Firefox o Edge. No hace falta
Xcode ni Android Studio para compilar la versión web.

## Ejecución

```bash
flutter pub get
flutter run -d web-server --web-port=3000
```

El backend local en el puerto 5001 es el valor por defecto. Para apuntar a otro:

```bash
flutter run -d web-server --web-port=3000 --dart-define=BACKEND_URL=https://mi-api.example
```

### Flags de compilación

Se pasan con `--dart-define` y se leen con `String.fromEnvironment` en `core/config.dart`.

| Flag | Valor por defecto | Efecto |
|---|---|---|
| `BACKEND_URL` | `http://localhost:5001` | Origen del backend. De él se derivan los tres siguientes |
| `API_URL` | `$BACKEND_URL/api` | Base de la API REST |
| `HUB_URL` | `$BACKEND_URL/hubs/chat` | Hub SignalR de mensajería |
| `SOCIAL_HUB_URL` | `$BACKEND_URL/hubs/social` | Hub SignalR de notificaciones |
| `DEMO_MODE` | `false` | Backend simulado en memoria, sin servidor |

Normalmente basta con `BACKEND_URL`; los otros tres existen para sobrescribir una URL
concreta. Con `DEMO_MODE=true`, un interceptor de Dio resuelve todas las peticiones contra
`core/api/demo_backend.dart` y los hubs no se conectan. Ninguna pantalla necesitó
modificarse para admitir ese modo. Ver [DEMO.md](../DEMO.md).

## Estructura

```
lib/
  main.dart                        Entrada, sesión y AppShell

  core/
    analytics/                     Eventos de Google Analytics, con stub fuera de web
    api/
      api_client.dart              Cliente Dio con JWT y despertar de la API
      demo_backend.dart            Backend simulado en memoria
      demo_interceptor.dart        Enruta las peticiones al backend simulado
    config.dart                    Flags de compilación
    models/user_profile.dart       UserProfile y UserRole
    services/                      ChatHubService y SocialHubService (SignalR)
    state/                         UserRoleController
    theme/                         KairosPalette, AppColors, AppTheme
    utils/                         Descarga de archivos y despertar de la API
    validation/                    Política de contraseñas, espejo de la del servidor
    widgets/                       AppShell, KCard, PostCard

  features/
    auth/       login, registro y pantalla de espera de aprobación
    home/       feed y tarjetas de competencias
    jobs/       ofertas, Quick Match y panel de la empresa
    network/    conexiones, solicitudes y sugerencias
    chat/       mensajería
    profile/    perfil, currículum y privacidad
    staff/      aprobaciones, usuarios, catálogo de competencias e historial
```

Las utilidades de `utils/` y el sumidero de analítica usan exportación condicional sobre
`dart.library.js_interop`, no sobre `dart.library.html`: esta última es falsa al compilar a
WebAssembly, y con ella una build wasm elegiría el stub y las descargas y la analítica
dejarían de funcionar sin dar ningún error.

## Roles

El rol viene del JWT y determina qué ve cada usuario.

| Rol | Valor | Diferencias |
|---|---|---|
| Estudiante | `student` | Feed, competencias, postulaciones, currículum |
| Egresado | `alumni` | Igual que estudiante, con insignia distinta |
| Empresa | `company` | Publicación de ofertas y búsqueda Quick Match |
| Staff | `staff` | Panel de gestión. Sin secciones de competencias ni currículum, y fuera de las sugerencias de la red |

En modo demo solo se ofrecen estudiante y empresa: el panel de gestión queda fuera del
alcance de los participantes de un estudio de usabilidad.

## Tema

`core/theme/kairos_palette.dart` define los tokens de color.

| Token | Color | Uso |
|---|---|---|
| `primary` | `#0F766E` | Botones principales y acentos |
| `accent` | `#00B5AD` | Estados hover, insignias, chips |
| `background` | `#F8FAFC` | Fondo de página |
| `card` | `#FFFFFF` | Superficie de tarjetas |
| `border` | `#E2E8F0` | Bordes |
| `muted` | `#E8F3EF` | Fondos secundarios |
| `foreground` | `#334155` | Texto principal |
| `secondary` | `#475569` | Texto secundario |

`AppColors` es una capa de alias sobre `KairosPalette`, conservada por compatibilidad. El
token de borde se llama `AppColors.divider`. La tipografía es Manrope, en pesos 400 a 900.
`KCard` es la tarjeta base, con sombra, borde y radio de 18 px.

Los contrastes están fijados por `test/contrast_tokens_test.dart`, que falla si una
combinación baja del mínimo AA.

## SignalR

Dos servicios en `core/services/`, ambos con reintentos automáticos a los 2, 5, 10 y 30
segundos. Si el backend no responde, degradan sin romper la interfaz, y en modo demo no
intentan conectarse.

- `chat_hub_service.dart` sobre `/hubs/chat`, para mensajería directa. Ciclo:
  `connect`, `joinConversation`, `onMessage.listen`, `sendMessage`, `leaveConversation`,
  `dispose`.
- `social_hub_service.dart` sobre `/hubs/social`, para me gusta, conexiones y comentarios.

## Tests

```bash
flutter analyze
flutter test
```

| Archivo | Cubre |
|---|---|
| `accessibility_controls_test.dart` | Etiquetas persistentes, semántica de controles, roles del registro |
| `accessibility_guidelines_test.dart` | Tamaño de objetivo táctil y reflujo a 320 px con texto al 200 % |
| `accessibility_shell_test.dart` | Salto al contenido principal por teclado |
| `web_accessibility_contract_test.dart` | Contrato del `index.html`: idioma, viewport ampliable |
| `contrast_tokens_test.dart` | Relación de contraste de la paleta |
| `password_policy_test.dart` | Que la regla del formulario sea la misma que la del servidor |
| `demo_chat_sides_test.dart` | Atribución de cada mensaje del chat a su remitente |

## Dependencias

| Paquete | Uso |
|---|---|
| `dio` | Cliente HTTP con interceptores |
| `signalr_netcore` | Cliente SignalR |
| `flutter_secure_storage` | Persistencia del JWT |
| `web` | Interoperabilidad con el navegador para descargas y analítica |
| `google_fonts` | Tipografía Manrope |
| `image_picker` | Imágenes de perfil y publicaciones |
| `file_picker` | Importación de alumnos por CSV |
