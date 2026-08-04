# Kairos — Frontend (Flutter)

Aplicación web construida en **Flutter 3 (Material 3)** para la plataforma Kairos.
Consume la API de [`backend/`](../backend/README.md) por HTTP y SignalR.

---

## Requisitos

| Herramienta | Versión mínima |
|---|---|
| Flutter SDK | 3.11.4 |
| Dart SDK | 3.x |
| Navegador | Chrome, Firefox o Edge |

No se requiere Xcode ni Android Studio para correr en web.

---

## Ejecutar

```bash
flutter pub get

# Contra el backend local (el --dart-define es obligatorio: sin él la app
# apunta a la URL de producción, que está caída)
flutter run -d web-server --web-port=3000 --dart-define=API_URL=http://localhost:5001/api
```

Abrir `http://localhost:3000`.

### Flags de compilación

Todos se pasan con `--dart-define` y se leen con `String.fromEnvironment`.

| Flag | Default | Efecto |
|---|---|---|
| `API_URL` | URL de Railway (caída) | Base de la API REST |
| `HUB_URL` | URL de Railway (caída) | Hub SignalR de chat |
| `DEMO_MODE` | `false` | Backend simulado en memoria, sin servidor |

**Modo demo:** con `DEMO_MODE=true` un interceptor de Dio responde todas las peticiones
desde `core/api/demo_backend.dart` y los hubs SignalR no se conectan. Sirve para estudios
de usabilidad sin infraestructura — ver [DEMO.md](../DEMO.md). El flag vive en
`core/config.dart` como `kDemoMode`.

---

## Estructura

```
lib/
├── main.dart                          # Entrada, routing y AppShell
│
├── core/
│   ├── analytics/
│   │   ├── analytics.dart             # Fachada de eventos GA (nombres en español)
│   │   ├── analytics_sink_web.dart    # Implementación web (window.kairosTrack)
│   │   └── analytics_sink_stub.dart   # No-op fuera de web
│   ├── api/
│   │   ├── api_client.dart            # Cliente HTTP (Dio) con JWT interceptor
│   │   ├── demo_backend.dart          # Backend simulado en memoria
│   │   └── demo_interceptor.dart      # Enruta las peticiones al backend simulado
│   ├── config.dart                    # kDemoMode
│   ├── data/mock_data.dart            # Datos de relleno de la UI
│   ├── models/user_profile.dart       # UserProfile, UserRole, SoftSkill
│   ├── services/
│   │   ├── chat_hub_service.dart      # SignalR — mensajería directa
│   │   └── social_hub_service.dart    # SignalR — likes, follows, comentarios
│   ├── state/user_role_controller.dart
│   ├── theme/                         # KairosPalette, AppTheme, AppColors
│   ├── utils/                         # Descarga de archivos (web / stub)
│   └── widgets/                       # AppShell, KCard, PostCard
│
└── features/
    ├── auth/       login_page · register_page
    ├── home/       home_page (feed) · post_model
    ├── jobs/       jobs_page (incluye Quick Match) · company_jobs_page · job_model
    ├── network/    network_page
    ├── chat/       chats_page · chat_model
    ├── profile/    profile_page
    └── staff/      registration_requests · user_management · staff_management
```

---

## Sistema de roles

El rol viene del JWT tras el login y determina qué ve cada usuario.

| Rol | Valor | Diferencias de UI |
|---|---|---|
| Estudiante | `student` | Feed estándar, registro de competencias, postulación a ofertas |
| Egresado | `alumni` | Mismo feed, insignia distinta |
| Docente / Staff | `staff` | Panel de gestión: aprobación de cuentas, usuarios, importación CSV |
| Empresa | `company` | Publicación de ofertas y búsqueda Quick Match en la pestaña Trabajos |

En modo demo solo se ofrecen **Estudiante** y **Empresa**: el rol `staff` se excluye a
propósito para que los testers no lleguen al panel de administración.

---

## Tema y diseño

### KairosPalette (`core/theme/kairos_palette.dart`)

| Token | Color | Uso |
|---|---|---|
| `primary` | `#0F766E` | Botones principales, acentos |
| `accent` | `#00B5AD` | Hover, insignias, chips |
| `background` | `#F8FAFC` | Fondo de página |
| `card` | `#FFFFFF` | Superficie de tarjetas |
| `border` | `#E2E8F0` | Bordes |
| `muted` | `#E8F3EF` | Fondos secundarios |
| `foreground` | `#334155` | Texto principal |
| `secondary` | `#475569` | Texto secundario |

`AppColors` es una capa de alias sobre `KairosPalette`, conservada por
compatibilidad con los widgets existentes. Nota: el token de borde se llama
`AppColors.divider`, no `AppColors.border`.

**Tipografía:** Manrope (Google Fonts), pesos 400–900.
**KCard:** tarjeta base con sombra, borde, radio de 18 px y gradiente opcional.

---

## API Client

`core/api/api_client.dart` usa **Dio** con el token JWT leído de
`FlutterSecureStorage` e inyectado en cada petición. Cubre los endpoints de
auth, posts, jobs, network, chat, skills, staff, curriculum y reports —
la lista completa está en el propio archivo.

---

## SignalR

Dos servicios en `core/services/`, ambos con reintentos automáticos
`[2 s, 5 s, 10 s, 30 s]`:

- **`chat_hub_service.dart`** → `/hubs/chat`. Mensajería directa.
  Ciclo: `connect()` → `joinConversation()` → `onMessage.listen()` →
  `sendMessage()` → `leaveConversation()` → `dispose()`.
  Eventos del servidor: `ReceiveMessage`, `UserTyping`.
- **`social_hub_service.dart`** → `/hubs/social`. Likes, seguimientos y
  comentarios en tiempo real. Eventos: `ReceiveLike`, `ReceiveFollow`,
  `ReceiveComment`, `UserTyping`.

Si el backend no está disponible, ambos degradan sin romper la UI.

> ⚠️ `social_hub_service.dart` tiene la URL del hub fijada a
> `http://localhost:5001/hubs/social`, sin leer `HUB_URL`. Fuera de desarrollo
> local no conecta — pendiente en la Fase 4 de [PRODUCCION.md](../PRODUCCION.md).

---

## Dependencias principales

| Paquete | Uso |
|---|---|
| `dio` | Cliente HTTP con interceptores |
| `signalr_netcore` | Cliente SignalR |
| `flutter_secure_storage` | Persistencia del JWT |
| `google_fonts` | Tipografía Manrope |
| `image_picker` | Selección de imágenes para perfil y publicaciones |
| `file_picker` | Importación CSV de alumnos (panel staff) |
