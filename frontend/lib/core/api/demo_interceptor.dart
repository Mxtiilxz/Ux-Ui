import 'package:dio/dio.dart';

import 'demo_backend.dart';

/// Intercepta todas las peticiones HTTP cuando la app corre en modo demo y las
/// resuelve con el backend simulado en memoria, sin salir a la red.
///
/// Concentrar la simulación acá evita tener que modificar cada pantalla: el
/// resto de la app sigue llamando al `ApiClient` exactamente igual.
class DemoInterceptor extends Interceptor {
  final _demo = DemoBackend.instance;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final data = await _route(options);
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: data,
      ));
    } catch (error) {
      handler.reject(DioException(
        requestOptions: options,
        error: error,
        message: 'Modo demo: operación no disponible.',
      ));
    }
  }

  Future<dynamic> _route(RequestOptions options) async {
    final method = options.method.toUpperCase();
    final segments = options.path
        .split('?')
        .first
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    final body = options.data is Map<String, dynamic>
        ? options.data as Map<String, dynamic>
        : const <String, dynamic>{};

    int idAt(int index) => int.tryParse(segments[index]) ?? 0;

    return switch (method) {
      'GET'    => await _get(segments, options, idAt),
      'POST'   => await _post(segments, body, idAt),
      'PUT'    => await _put(segments, body, idAt),
      'DELETE' => await _delete(segments, idAt),
      _        => <String, dynamic>{},
    };
  }

  Future<dynamic> _get(
    List<String> s,
    RequestOptions options,
    int Function(int) idAt,
  ) async {
    // posts
    if (_is(s, ['posts', 'feed'])) return _demo.getFeed();
    if (s.length == 3 && s[0] == 'posts' && s[2] == 'comments') {
      return _demo.getComments(idAt(1));
    }

    // jobs
    if (_is(s, ['jobs'])) return _demo.getJobs();
    if (_is(s, ['jobs', 'my-postings'])) return _demo.getMyJobPostings();
    if (s.length == 3 && s[0] == 'jobs' && s[2] == 'applications') {
      return _demo.getJobApplications(idAt(1));
    }

    // skills / quick match
    if (_is(s, ['skills'])) return _demo.getSkills();
    if (_is(s, ['skills', 'me'])) return _demo.getMySkills();
    if (_is(s, ['skills', 'company', 'message'])) {
      return _demo.getCompanyMessageTemplate();
    }
    if (_is(s, ['skills', 'candidates'])) {
      final raw = options.queryParameters['skillIds']?.toString() ?? '';
      final ids = raw
          .split(',')
          .map((v) => int.tryParse(v.trim()))
          .whereType<int>()
          .toList();
      return _demo.searchCandidates(ids);
    }

    // network
    if (_is(s, ['network', 'suggestions'])) return _demo.getNetworkSuggestions();
    if (_is(s, ['network', 'following'])) return _demo.getFollowing();

    // chat
    if (_is(s, ['chat', 'conversations'])) return _demo.getConversations();
    if (s.length == 3 && s[0] == 'chat' && s[1] == 'messages') {
      return _demo.getMessages(idAt(2));
    }

    // El panel de staff no está disponible para los testers del modo demo.
    if (s.isNotEmpty && s[0] == 'staff') return <dynamic>[];

    return <dynamic>[];
  }

  Future<dynamic> _post(
    List<String> s,
    Map<String, dynamic> body,
    int Function(int) idAt,
  ) async {
    // posts
    if (_is(s, ['posts'])) {
      return _demo.createPost(
        content: body['content'] as String? ?? '',
        postType: body['postType'] as String? ?? 'general',
        imageUrl: body['imageUrl'] as String?,
        eventDate: body['eventDate'] as String?,
      );
    }
    if (s.length == 3 && s[0] == 'posts' && s[2] == 'like') {
      return _demo.toggleLike(idAt(1));
    }
    if (s.length == 3 && s[0] == 'posts' && s[2] == 'comments') {
      return _demo.addComment(idAt(1), body['content'] as String? ?? '');
    }

    // jobs
    if (_is(s, ['jobs'])) {
      return _demo.createJobPosting(
        title: body['title'] as String? ?? '',
        description: body['description'] as String? ?? '',
        location: body['location'] as String?,
        imageUrl: body['imageUrl'] as String?,
      );
    }
    if (s.length == 3 && s[0] == 'jobs' && s[2] == 'apply') {
      return _demo.applyToJob(idAt(1));
    }

    // skills
    if (s.length == 3 && s[0] == 'skills' && s[1] == 'me') {
      await _demo.addMySkill(idAt(2));
      return null;
    }

    // network
    if (s.length == 3 && s[0] == 'network' && s[2] == 'follow') {
      await _demo.followUser(idAt(1));
      return null;
    }

    // chat
    if (s.length == 3 && s[0] == 'chat' && s[1] == 'messages') {
      return _demo.sendMessage(idAt(2), body['content'] as String? ?? '');
    }

    // auth
    if (_is(s, ['auth', 'register'])) {
      return {'userId': 900, 'email': body['email'] ?? 'demo@kairos.cl'};
    }

    return null;
  }

  Future<dynamic> _put(
    List<String> s,
    Map<String, dynamic> body,
    int Function(int) idAt,
  ) async {
    if (_is(s, ['skills', 'me', 'visibility'])) {
      final visible = await _demo.setQuickMatchVisibility(body['visible'] as bool? ?? false);
      return {'visible': visible};
    }
    if (_is(s, ['skills', 'company', 'message'])) {
      return _demo.setCompanyMessageTemplate(body['template'] as String? ?? '');
    }
    if (s.length == 2 && s[0] == 'posts') {
      await _demo.updatePost(idAt(1), body['content'] as String? ?? '');
      return null;
    }
    if (s.length == 2 && s[0] == 'jobs') {
      await _demo.updateJobPosting(idAt(1), {
        if (body['title'] != null)       'title': body['title'],
        if (body['description'] != null) 'description': body['description'],
        if (body['location'] != null)    'location': body['location'],
        if (body['imageUrl'] != null)    'imageUrl': body['imageUrl'],
      });
      return null;
    }
    return null;
  }

  Future<dynamic> _delete(List<String> s, int Function(int) idAt) async {
    if (s.length == 3 && s[0] == 'skills' && s[1] == 'me') {
      await _demo.removeMySkill(idAt(2));
      return null;
    }
    if (s.length == 3 && s[0] == 'network' && s[2] == 'follow') {
      await _demo.unfollowUser(idAt(1));
      return null;
    }
    if (s.length == 2 && s[0] == 'posts') {
      await _demo.deletePost(idAt(1));
      return null;
    }
    if (s.length == 2 && s[0] == 'jobs') {
      await _demo.deleteJobPosting(idAt(1));
      return null;
    }
    return null;
  }

  static bool _is(List<String> segments, List<String> expected) {
    if (segments.length != expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (segments[i] != expected[i]) return false;
    }
    return true;
  }
}
