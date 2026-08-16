/// Contenido fijo de la interfaz.
///
/// Este archivo reemplaza al antiguo `mock_data.dart`, del que solo quedaban en
/// uso estas dos listas: el resto —usuarios, publicaciones y ofertas de
/// ejemplo— servía de relleno cuando la API no respondía, y se eliminó al
/// conectar la aplicación a un backend real.
///
/// Ojo con el nombre de la primera: son competencias **fijas**, elegidas a mano
/// para el liceo, no un cálculo de lo que más se busca. Si en algún momento se
/// quieren tendencias de verdad, salen de contar `user_skills` en la base de
/// datos, y entonces esta lista desaparece.
library;

/// Competencias destacadas que se muestran como chips en la barra lateral.
const List<String> trendingSkills = [
  'Soldadura',
  'PLC',
  'AutoCAD',
  'Mantenimiento',
  'CNC',
];

/// Oficios del liceo, para la sección de exploración por rubro.
const List<String> highlightedTrades = [
  'Electricista',
  'Soldador',
  'Carpintero',
  'Mecanico',
  'Fontanero',
];
