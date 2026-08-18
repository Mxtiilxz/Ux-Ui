/// Exportación condicional: en el navegador usa `package:web`, en el resto de
/// plataformas exporta funciones vacías.
///
/// La condición es `dart.library.js_interop` y no `dart.library.html`: esta
/// última es falsa al compilar a WebAssembly, así que una build wasm elegiría
/// el stub y las descargas dejarían de funcionar sin avisar.
library;

export 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';
