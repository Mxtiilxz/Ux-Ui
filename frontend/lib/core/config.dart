/// Modo demostración: la app funciona sin backend, usando datos simulados en
/// memoria. Se activa al compilar con `--dart-define=DEMO_MODE=true`.
///
/// Vive en su propio archivo para que tanto el cliente HTTP como los servicios
/// de tiempo real puedan consultarlo sin depender unos de otros.
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE');
