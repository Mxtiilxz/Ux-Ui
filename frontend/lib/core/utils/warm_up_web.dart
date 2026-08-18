import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Envía una petición a [url] solo para que el servidor arranque.
///
/// Va en modo `no-cors` a propósito. La respuesta no interesa —lo único que se
/// busca es que el contenedor dormido reciba tráfico—, y una petición normal
/// desde un origen que la API no tenga en su lista de CORS dejaría dos errores
/// rojos en la consola del navegador en cada carga. Eso pasaría, por ejemplo,
/// en una URL de vista previa de Netlify, cuyo hostname cambia en cada
/// despliegue y no está en la lista.
///
/// Con `no-cors` el navegador manda la petición igual y devuelve una respuesta
/// opaca, sin registrar ningún error.
void warmUpPing(String url) {
  try {
    web.window.fetch(
      url.toJS,
      web.RequestInit(mode: 'no-cors', cache: 'no-store'),
    );
  } catch (_) {
    // Despertar el servidor es best-effort: nunca debe interrumpir el arranque.
  }
}
