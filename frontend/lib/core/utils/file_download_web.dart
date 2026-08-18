import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Dispara la descarga de [bytes] en el navegador usando una URL de blob
/// temporal.
void downloadFile(List<int> bytes, String filename) {
  final blob = web.Blob(
    <JSUint8Array>[Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  anchor.click();

  // La URL de blob retiene el archivo en memoria hasta que se revoca.
  web.URL.revokeObjectURL(url);
}

/// Abre [url] en una pestaña nueva.
///
/// Se usa para archivos que ya viven en Supabase Storage —el CV que adjunta un
/// postulante, por ejemplo—, donde no hace falta traer los bytes a la
/// aplicación solo para volver a entregarlos al navegador.
///
/// `noopener` evita que la página abierta pueda manipular a la que la abrió.
void openUrl(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
