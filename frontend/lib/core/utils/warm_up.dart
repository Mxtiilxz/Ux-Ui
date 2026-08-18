/// Exportación condicional del despertar de la API. Ver `warm_up_web.dart`.
library;

export 'warm_up_stub.dart' if (dart.library.js_interop) 'warm_up_web.dart';
