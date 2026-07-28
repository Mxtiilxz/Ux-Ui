import 'dart:js' as js;

/// Envía un evento a Google Analytics a través de `window.kairosTrack`,
/// definida en `web/index.html`. Si GA no está configurado, la función del
/// navegador simplemente no hace nada.
void sendEvent(String name, Map<String, Object?> params) {
  try {
    js.context.callMethod('kairosTrack', [name, js.JsObject.jsify(params)]);
  } catch (_) {
    // Nunca dejar que la analítica rompa la experiencia del usuario.
  }
}
