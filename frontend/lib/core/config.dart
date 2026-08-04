/// Modo demostración: la app funciona sin backend, usando datos simulados en
/// memoria. Se activa al compilar con `--dart-define=DEMO_MODE=true`.
///
/// Vive en su propio archivo para que tanto el cliente HTTP como los servicios
/// de tiempo real puedan consultarlo sin depender unos de otros.
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE');

/// Origen del backend, sin la ruta `/api` ni la de los hubs.
///
/// Se define al compilar con `--dart-define=BACKEND_URL=https://mi-api.example`.
/// De aquí se derivan la URL de la API y las de los dos hubs SignalR, para que
/// baste un solo indicador al compilar en vez de tres que puedan desincronizarse.
const String kBackendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://localhost:5001',
);

/// URL base de la API REST. `API_URL` tiene prioridad por compatibilidad con las
/// instrucciones de compilación previas.
const String kApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: '$kBackendUrl/api',
);

/// Hub SignalR de mensajería directa.
const String kChatHubUrl = String.fromEnvironment(
  'HUB_URL',
  defaultValue: '$kBackendUrl/hubs/chat',
);

/// Hub SignalR de notificaciones sociales (likes, seguimientos, comentarios).
const String kSocialHubUrl = String.fromEnvironment(
  'SOCIAL_HUB_URL',
  defaultValue: '$kBackendUrl/hubs/social',
);
