import 'analytics_sink_stub.dart' if (dart.library.html) 'analytics_sink_web.dart';

/// Punto único de registro de interacciones para Google Analytics.
///
/// Cada método corresponde a una acción concreta del usuario. Mantener los
/// nombres de evento acá (y no dispersos por las pantallas) permite revisar de
/// un vistazo qué se está midiendo en el estudio de uso.
class Analytics {
  const Analytics._();

  static void _send(String name, [Map<String, Object?> params = const {}]) {
    sendEvent(name, params);
  }

  // ── Sesión y navegación ────────────────────────────────────────────────────

  /// Perfil con el que el tester decide recorrer la plataforma.
  static void login(String role) => _send('login', {'method': 'demo', 'rol': role});

  static void logout() => _send('logout');

  /// Cambio de pestaña en la barra principal.
  static void tabView(String tab) =>
      _send('ver_pestana', {'pestana': tab});

  // ── Feed ───────────────────────────────────────────────────────────────────

  static void postLike(bool liked) =>
      _send('post_like', {'accion': liked ? 'dar' : 'quitar'});

  static void postCreate(String postType) =>
      _send('post_publicar', {'tipo': postType});

  static void postComment() => _send('post_comentar');

  static void postShare() => _send('post_compartir');

  // ── Ofertas laborales ──────────────────────────────────────────────────────

  static void jobApply(String jobTitle) =>
      _send('oferta_postular', {'oferta': jobTitle});

  static void jobCreate() => _send('oferta_publicar');

  static void jobViewApplicants() => _send('oferta_ver_postulantes');

  // ── Quick Match ────────────────────────────────────────────────────────────

  static void quickMatchSkillToggle(String skill, bool selected) =>
      _send('quickmatch_filtro', {
        'competencia': skill,
        'accion': selected ? 'agregar' : 'quitar',
      });

  static void quickMatchSearch(int skillCount, int resultCount) =>
      _send('quickmatch_buscar', {
        'competencias_buscadas': skillCount,
        'candidatos_encontrados': resultCount,
      });

  static void quickMatchContact(int matchPercentage) =>
      _send('quickmatch_contactar', {'coincidencia': matchPercentage});

  // ── Perfil y competencias ──────────────────────────────────────────────────

  static void skillToggle(String skill, bool added) =>
      _send('competencia_perfil', {
        'competencia': skill,
        'accion': added ? 'agregar' : 'quitar',
      });

  static void quickMatchVisibility(bool visible) =>
      _send('quickmatch_visibilidad', {'visible': visible});

  static void downloadCv() => _send('descargar_cv');

  static void downloadReport() => _send('descargar_reporte');

  // ── Red y mensajería ───────────────────────────────────────────────────────

  static void follow(bool following) =>
      _send('red_seguir', {'accion': following ? 'seguir' : 'dejar'});

  static void sendMessage() => _send('chat_enviar_mensaje');
}
