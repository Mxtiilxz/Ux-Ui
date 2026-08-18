import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Envía un evento a Google Analytics a través de `window.kairosTrack`,
/// definida en `web/index.html`. Si GA no está configurado, la función del
/// navegador simplemente no hace nada.
void sendEvent(String name, Map<String, Object?> params) {
  try {
    // La función puede no existir: `index.html` solo la define cuando hay un ID
    // de medición configurado.
    if (!globalContext.has('kairosTrack')) return;
    globalContext.callMethod('kairosTrack'.toJS, name.toJS, params.jsify());
  } catch (_) {
    // Nunca dejar que la analítica rompa la experiencia del usuario.
  }
}
