import 'dart:convert';

/// Backend simulado en memoria para el modo demo (sin servidor).
///
/// Permite testear la experiencia completa en un despliegue estático: los
/// cambios que hace el usuario (publicar, dar like, comentar, agregar
/// competencias, contactar candidatos) se reflejan durante la sesión y se
/// reinician al recargar la página.
class DemoBackend {
  DemoBackend._();
  static final DemoBackend instance = DemoBackend._();

  // ── Sesión actual ──────────────────────────────────────────────────────────
  int _currentUserId = 900;
  String _currentUserRole = 'student';
  String _currentUserName = 'Usuario Demo';

  void setCurrentUser({
    required int id,
    required String role,
    required String name,
  }) {
    _currentUserId = id;
    _currentUserRole = role;
    _currentUserName = name;
  }

  /// Devuelve el estado a su punto inicial (se llama al cerrar sesión).
  void reset() {
    _posts
      ..clear()
      ..addAll(_initialPosts());
    _likedPostIds.clear();
    _commentsByPost.clear();
    _mySkillIds
      ..clear()
      ..addAll([1, 2, 3, 12, 14]);
    _quickMatchVisible = true;
    _messageTemplate = null;
    _followingIds
      ..clear()
      ..addAll([101, 104]);
    _conversations
      ..clear()
      ..addAll(_initialConversations());
    _messagesByUser.clear();
    _jobs
      ..clear()
      ..addAll(_initialJobs());
    _appliedJobIds.clear();
    _savedJobIds.clear();
    _nextId = 5000;
  }

  int _nextId = 5000;
  int _newId() => _nextId++;

  /// Latencia simulada para que los indicadores de carga se comporten igual
  /// que contra un servidor real.
  Future<T> _delayed<T>(T value, [int ms = 220]) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    return value;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CATÁLOGO DE COMPETENCIAS  (mismo contenido que el seeder del backend)
  // ════════════════════════════════════════════════════════════════════════

  static const List<Map<String, dynamic>> _skills = [
    {'id': 1, 'name': 'PLC Siemens', 'category': 'Technical'},
    {'id': 2, 'name': 'Arduino', 'category': 'Technical'},
    {'id': 3, 'name': 'SolidWorks', 'category': 'Technical'},
    {'id': 4, 'name': 'AutoCAD', 'category': 'Technical'},
    {'id': 5, 'name': 'Python', 'category': 'Technical'},
    {'id': 6, 'name': 'C/C++', 'category': 'Technical'},
    {'id': 7, 'name': 'Redes', 'category': 'Technical'},
    {'id': 8, 'name': 'Modbus', 'category': 'Technical'},
    {'id': 9, 'name': 'Robótica industrial', 'category': 'Technical'},
    {'id': 10, 'name': 'Diseño 3D', 'category': 'Technical'},
    {'id': 11, 'name': 'Inglés B1', 'category': 'Language'},
    {'id': 12, 'name': 'Inglés B2', 'category': 'Language'},
    {'id': 13, 'name': 'Inglés C1', 'category': 'Language'},
    {'id': 14, 'name': 'Práctica en automatización', 'category': 'Experience'},
    {'id': 15, 'name': 'Práctica en TI', 'category': 'Experience'},
    {'id': 16, 'name': 'Proyecto personal publicado', 'category': 'Experience'},
    // Competencias agregadas después. Van al final para no mover los IDs 1-16,
    // que los candidatos de esta misma demo referencian más abajo.
    {'id': 17, 'name': 'Soldadura al arco', 'category': 'Technical'},
    {'id': 18, 'name': 'Instalaciones eléctricas', 'category': 'Technical'},
    {'id': 19, 'name': 'Mantenimiento mecánico', 'category': 'Technical'},
    {'id': 20, 'name': 'Torno y fresado CNC', 'category': 'Technical'},
    {'id': 21, 'name': 'Neumática e hidráulica', 'category': 'Technical'},
    {'id': 22, 'name': 'Lectura de planos', 'category': 'Technical'},
    {'id': 23, 'name': 'Prevención de riesgos', 'category': 'Technical'},
    {'id': 24, 'name': 'Práctica en mantenimiento', 'category': 'Experience'},
    {
      'id': 25,
      'name': 'Licencia de conducir clase B',
      'category': 'Experience',
    },
  ];

  // ════════════════════════════════════════════════════════════════════════
  //  ESTUDIANTES DEMO  (candidatos de Quick Match + red de contactos)
  // ════════════════════════════════════════════════════════════════════════

  static const String _liceo = 'Liceo Técnico Cardenal José María Caro';

  static const List<Map<String, dynamic>> _people = [
    {
      'id': 101,
      'fullName': 'Camila Vidal Astorga',
      'role': 'student',
      'title': 'Estudiante · Mecatrónica',
      'institution': _liceo,
      'bio':
          'Cuarto medio en Mecatrónica. Me interesa la automatización industrial.',
      'skillIds': [1, 2, 3, 12, 14],
      'followers': 24,
    },
    {
      'id': 102,
      'fullName': 'Joaquín Torres Peña',
      'role': 'student',
      'title': 'Estudiante · Programación',
      'institution': _liceo,
      'bio': 'Programación y control de microcontroladores.',
      'skillIds': [1, 2, 5, 11],
      'followers': 18,
    },
    {
      'id': 103,
      'fullName': 'Fernanda Rojas Muñoz',
      'role': 'student',
      'title': 'Estudiante · Informática',
      'institution': _liceo,
      'bio': 'Desarrollo de software y soporte de infraestructura.',
      'skillIds': [4, 5, 6, 13, 15],
      'followers': 31,
    },
    {
      'id': 104,
      'fullName': 'Matías Herrera Lagos',
      'role': 'student',
      'title': 'Estudiante · Telecomunicaciones',
      'institution': _liceo,
      'bio': 'Redes industriales y protocolos de comunicación.',
      'skillIds': [1, 7, 8, 11],
      'followers': 12,
    },
    {
      'id': 105,
      'fullName': 'Valentina Soto Cárdenas',
      'role': 'student',
      'title': 'Estudiante · Diseño Industrial',
      'institution': _liceo,
      'bio': 'Modelado 3D y prototipado rápido.',
      'skillIds': [3, 4, 10, 12, 16],
      'followers': 27,
    },
    {
      'id': 106,
      'fullName': 'Ignacio Fuentes Bravo',
      'role': 'student',
      'title': 'Estudiante · Mecatrónica',
      'institution': _liceo,
      'bio': 'Robótica y sistemas embebidos.',
      'skillIds': [2, 6, 9, 16],
      'followers': 15,
    },
    {
      'id': 201,
      'fullName': 'Automatización Industrial S.A.',
      'role': 'company',
      'title': 'Empresa',
      'institution': 'Santiago, Chile',
      'bio': 'Soluciones de automatización para la industria nacional.',
      'skillIds': <int>[],
      'followers': 140,
    },
    {
      'id': 202,
      'fullName': 'TechSolutions Chile SpA',
      'role': 'company',
      'title': 'Empresa',
      'institution': 'Viña del Mar, Chile',
      'bio': 'Software y sistemas embebidos para minería y energía.',
      'skillIds': <int>[],
      'followers': 96,
    },
  ];

  static Map<String, dynamic>? _personById(int id) {
    for (final p in _people) {
      if (p['id'] == id) return p;
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  ESTADO MUTABLE
  // ════════════════════════════════════════════════════════════════════════

  static String _iso(Duration ago) =>
      DateTime.now().toUtc().subtract(ago).toIso8601String();

  List<Map<String, dynamic>> _initialPosts() => [
    {
      'id': 1,
      'authorId': 101,
      'authorName': 'Camila Vidal Astorga',
      'authorRole': 'student',
      'authorProfilePictureUrl': null,
      'content':
          '¡Terminé mi proyecto de brazo robótico controlado por Arduino! '
          'Fue un desafío aprender a coordinar los servomotores, pero quedó funcionando. '
          'Gracias a todos los que me apoyaron.',
      'postType': 'general',
      'imageUrl': null,
      'eventDate': null,
      'likesCount': 24,
      'commentsCount': 2,
      'createdAt': _iso(const Duration(hours: 5)),
    },
    {
      'id': 2,
      'authorId': 201,
      'authorName': 'Automatización Industrial S.A.',
      'authorRole': 'company',
      'authorProfilePictureUrl': null,
      'content':
          'Abrimos dos cupos de práctica profesional para estudiantes de '
          'Mecatrónica. Si te apasiona la automatización industrial, revisa la '
          'oferta en la pestaña Trabajos.',
      'postType': 'general',
      'imageUrl': null,
      'eventDate': null,
      'likesCount': 41,
      'commentsCount': 1,
      'createdAt': _iso(const Duration(hours: 12)),
    },
    {
      'id': 3,
      'authorId': 202,
      'authorName': 'TechSolutions Chile SpA',
      'authorRole': 'company',
      'authorProfilePictureUrl': null,
      'content':
          'Charla abierta: "Cómo preparar tu primera entrevista técnica". '
          'Inscripciones abiertas para estudiantes de 3° y 4° medio.',
      'postType': 'event',
      'imageUrl': null,
      'eventDate': DateTime.now()
          .add(const Duration(days: 9))
          .toIso8601String()
          .substring(0, 10),
      'likesCount': 33,
      'commentsCount': 0,
      'createdAt': _iso(const Duration(days: 1, hours: 3)),
    },
    {
      'id': 4,
      'authorId': 105,
      'authorName': 'Valentina Soto Cárdenas',
      'authorRole': 'student',
      'authorProfilePictureUrl': null,
      'content':
          'Subí a mi perfil el modelado 3D de la pieza que diseñamos en el '
          'taller. Cualquier feedback es bienvenido.',
      'postType': 'general',
      'imageUrl': null,
      'eventDate': null,
      'likesCount': 17,
      'commentsCount': 0,
      'createdAt': _iso(const Duration(days: 2)),
    },
  ];

  List<Map<String, dynamic>> _initialJobs() => [
    {
      'id': 1,
      'title': 'Técnico en Automatización Industrial',
      'description':
          'Buscamos egresado o estudiante de último año en Mecatrónica. '
          'Trabajarás en automatización de líneas de producción con PLCs Siemens.',
      'location': 'Pudahuel, Santiago',
      'imageUrl': null,
      'status': 'Open',
      'createdAt': _iso(const Duration(days: 7)),
      'expiresAt': DateTime.now()
          .add(const Duration(days: 23))
          .toIso8601String(),
      'companyId': 201,
      'companyName': 'Automatización Industrial S.A.',
      'companyAvatarUrl': null,
      'skillIds': [1, 8, 22],
      'applicationCount': 3,
    },
    {
      'id': 2,
      'title': 'Práctica Profesional — Programación PLC',
      'description':
          'Práctica de 6 meses para estudiantes de 4° año. Aprenderás a '
          'programar PLCs en lenguaje Ladder y a configurar HMI industriales.',
      'location': 'Maipú, Santiago',
      'imageUrl': null,
      'status': 'Open',
      'createdAt': _iso(const Duration(days: 3)),
      'expiresAt': DateTime.now()
          .add(const Duration(days: 27))
          .toIso8601String(),
      'companyId': 201,
      'companyName': 'Automatización Industrial S.A.',
      'companyAvatarUrl': null,
      'skillIds': [1, 14, 12],
      'applicationCount': 1,
    },
    {
      'id': 3,
      'title': 'Desarrollador de Sistemas Embebidos',
      'description':
          'Buscamos técnico con conocimientos en C/C++ para '
          'microcontroladores y comunicación industrial (Modbus, CAN).',
      'location': 'Antofagasta / Remoto',
      'imageUrl': null,
      'status': 'Open',
      'createdAt': _iso(const Duration(days: 5)),
      'expiresAt': DateTime.now()
          .add(const Duration(days: 25))
          .toIso8601String(),
      'companyId': 202,
      'companyName': 'TechSolutions Chile SpA',
      'companyAvatarUrl': null,
      'skillIds': [2, 5, 6],
      'applicationCount': 0,
    },
    {
      'id': 4,
      'title': 'Práctica — Soporte IT e Infraestructura',
      'description':
          'Práctica de 4 meses. Apoyarás al equipo en mantención de '
          'redes, servidores Linux y monitoreo de sistemas.',
      'location': 'Viña del Mar',
      'imageUrl': null,
      'status': 'Open',
      'createdAt': _iso(const Duration(days: 1)),
      'expiresAt': DateTime.now()
          .add(const Duration(days: 29))
          .toIso8601String(),
      'companyId': 202,
      'companyName': 'TechSolutions Chile SpA',
      'companyAvatarUrl': null,
      'skillIds': [4, 10, 3],
      'applicationCount': 2,
    },
  ];

  List<Map<String, dynamic>> _initialConversations() => [
    {
      'otherUserId': 101,
      'otherUserName': 'Camila Vidal Astorga',
      'otherUserRole': 'student',
      'otherUserTitle': 'Estudiante · Mecatrónica',
      'otherUserAvatarUrl': '',
      'lastMessage': '¡Gracias! Me interesa mucho la oferta.',
      'lastMessageAt': _iso(const Duration(hours: 2)),
      'hasUnread': true,
    },
    {
      'otherUserId': 104,
      'otherUserName': 'Matías Herrera Lagos',
      'otherUserRole': 'student',
      'otherUserTitle': 'Estudiante · Telecomunicaciones',
      'otherUserAvatarUrl': '',
      'lastMessage': 'Buenas, ¿la práctica es presencial?',
      'lastMessageAt': _iso(const Duration(days: 1)),
      'hasUnread': false,
    },
  ];

  late final List<Map<String, dynamic>> _posts = _initialPosts();
  late final List<Map<String, dynamic>> _jobs = _initialJobs();
  late final List<Map<String, dynamic>> _conversations =
      _initialConversations();

  final Set<int> _likedPostIds = {};
  final Map<int, List<Map<String, dynamic>>> _commentsByPost = {};
  final Map<int, List<Map<String, dynamic>>> _messagesByUser = {};
  final Set<int> _mySkillIds = {1, 2, 3, 12, 14};
  final Set<int> _followingIds = {101, 104};
  final Set<int> _appliedJobIds = {};
  bool _quickMatchVisible = true;

  /// Plantilla de contacto de Quick Match. Debe coincidir con
  /// `QuickMatchDefaults.MessageTemplate` del backend real.
  static const String defaultMessageTemplate =
      'Hola {nombre}, te contactamos desde {empresa}. Vimos que dominas '
      '{competencias} y nos encantaría conversar contigo sobre una oportunidad '
      'de práctica. ¿Te interesaría?';

  String? _messageTemplate;

  Future<Map<String, dynamic>> getCompanyMessageTemplate() => _delayed({
    'template': _messageTemplate ?? defaultMessageTemplate,
    'isDefault': _messageTemplate == null,
  });

  Future<Map<String, dynamic>> setCompanyMessageTemplate(String template) {
    final trimmed = template.trim();
    _messageTemplate = trimmed.isEmpty ? null : trimmed;
    return _delayed({
      'template': _messageTemplate ?? defaultMessageTemplate,
      'isDefault': _messageTemplate == null,
    }, 180);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  AUTENTICACIÓN
  // ════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> login(String email, String role, String name) {
    final id = role == 'company' ? 201 : 900;
    setCurrentUser(id: id, role: role, name: name);
    return _delayed({
      'userId': id,
      'token': 'demo-token',
      'fullName': name,
      'profilePictureUrl': null,
      'role': role,
      'institution': role == 'company' ? 'Santiago, Chile' : _liceo,
      'quickMatchVisible': _quickMatchVisible,
    }, 400);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  FEED / PUBLICACIONES
  // ════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getFeed() => _delayed({
    'items': List<Map<String, dynamic>>.from(_posts),
    'totalCount': _posts.length,
    'hasNextPage': false,
  });

  Future<int> createPost({
    required String content,
    String postType = 'general',
    String? imageUrl,
    String? imageAltText,
    String? eventDate,
  }) {
    final id = _newId();
    _posts.insert(0, {
      'id': id,
      'authorId': _currentUserId,
      'authorName': _currentUserName,
      'authorRole': _currentUserRole,
      'authorProfilePictureUrl': null,
      'content': content,
      'postType': postType,
      'imageUrl': imageUrl,
      'imageAltText': imageAltText,
      'eventDate': eventDate,
      'likesCount': 0,
      'commentsCount': 0,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    return _delayed(id);
  }

  Future<Map<String, dynamic>> toggleLike(int postId) {
    final post = _posts.firstWhere((p) => p['id'] == postId, orElse: () => {});
    if (post.isEmpty) return _delayed({'likesCount': 0});

    final liked = _likedPostIds.contains(postId);
    final count = (post['likesCount'] as int? ?? 0) + (liked ? -1 : 1);
    post['likesCount'] = count < 0 ? 0 : count;
    liked ? _likedPostIds.remove(postId) : _likedPostIds.add(postId);

    return _delayed({'likesCount': post['likesCount']}, 120);
  }

  Future<List<Map<String, dynamic>>> getComments(int postId) {
    final seeded = <int, List<Map<String, dynamic>>>{
      1: [
        {
          'id': 91,
          'authorName': 'Matías Herrera Lagos',
          'authorAvatarUrl': '',
          'content': 'Quedó excelente, ¿qué servos usaste?',
          'createdAt': _iso(const Duration(hours: 4)),
        },
        {
          'id': 92,
          'authorName': 'Valentina Soto Cárdenas',
          'authorAvatarUrl': '',
          'content': 'Muy buen trabajo 👏',
          'createdAt': _iso(const Duration(hours: 3)),
        },
      ],
      2: [
        {
          'id': 93,
          'authorName': 'Joaquín Torres Peña',
          'authorAvatarUrl': '',
          'content': '¿Hasta cuándo se puede postular?',
          'createdAt': _iso(const Duration(hours: 8)),
        },
      ],
    };
    final list = _commentsByPost.putIfAbsent(
      postId,
      () => List<Map<String, dynamic>>.from(seeded[postId] ?? const []),
    );
    return _delayed(List<Map<String, dynamic>>.from(list));
  }

  Future<Map<String, dynamic>> addComment(int postId, String content) {
    final comment = {
      'id': _newId(),
      'authorName': _currentUserName,
      'authorAvatarUrl': '',
      'content': content,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    _commentsByPost.putIfAbsent(postId, () => []).add(comment);

    final post = _posts.firstWhere((p) => p['id'] == postId, orElse: () => {});
    if (post.isNotEmpty) {
      post['commentsCount'] = (post['commentsCount'] as int? ?? 0) + 1;
    }
    return _delayed(comment, 150);
  }

  Future<void> deletePost(int postId) {
    _posts.removeWhere((p) => p['id'] == postId);
    return _delayed(null);
  }

  Future<void> updatePost(int postId, String content) {
    final post = _posts.firstWhere((p) => p['id'] == postId, orElse: () => {});
    if (post.isNotEmpty) post['content'] = content;
    return _delayed(null);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  OFERTAS LABORALES
  // ════════════════════════════════════════════════════════════════════════

  /// Expande los `skillIds` de una oferta a la forma que devuelve el backend
  /// real: una lista de objetos con id, nombre y categoría.
  Map<String, dynamic> _withSkills(Map<String, dynamic> job) {
    final ids = (job['skillIds'] as List<dynamic>? ?? []).cast<int>();
    return {
      ...job,
      'skills': _skills
          .where((skill) => ids.contains(skill['id']))
          .map((skill) => Map<String, dynamic>.from(skill))
          .toList(),
    };
  }

  // ── Perfil propio ──────────────────────────────────────────────────────────

  final Map<String, dynamic> _myProfileEdits = {};

  Future<Map<String, dynamic>> getMyProfile() => _delayed({
    'id': _currentUserId,
    'username': _currentUserName,
    'email': 'demo@kairos.cl',
    'fullName': _currentUserName,
    'bio': null,
    'institution': _liceo,
    'profilePictureUrl': null,
    'role': _currentUserRole,
    'status': 'approved',
    'quickMatchVisible': _quickMatchVisible,
    'postCount': _posts.where((p) => p['authorId'] == _currentUserId).length,
    'skillCount': _mySkillIds.length,
    'followingCount': _followingIds.length,
    // En la demo nadie sigue al usuario: no hay otras sesiones que lo hagan.
    'followerCount': 0,
    ..._myProfileEdits,
  });

  Future<Map<String, dynamic>> updateMyProfile(Map<String, dynamic> body) {
    _myProfileEdits.addAll({
      'fullName': body['fullName'],
      'bio': body['bio'],
      'institution': body['institution'],
      'profilePictureUrl': body['profilePictureUrl'],
    });
    _currentUserName = body['fullName'] as String? ?? _currentUserName;
    return getMyProfile();
  }

  final Set<int> _savedJobIds = <int>{};

  Future<List<int>> getSavedJobs() => _delayed(_savedJobIds.toList());

  Future<Map<String, dynamic>> toggleSavedJob(int jobId) {
    final saved = !_savedJobIds.contains(jobId);
    if (saved) {
      _savedJobIds.add(jobId);
    } else {
      _savedJobIds.remove(jobId);
    }
    return _delayed({'saved': saved});
  }

  Future<Map<String, dynamic>> getJobs() => _delayed({
    'items': _jobs.map(_withSkills).toList(),
    'totalCount': _jobs.length,
    'hasNextPage': false,
  });

  Future<int> createJobPosting({
    required String title,
    required String description,
    String? location,
    String? imageUrl,
    List<int> skillIds = const [],
  }) {
    final id = _newId();
    _jobs.insert(0, {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'imageUrl': imageUrl,
      'skillIds': skillIds,
      'status': 'Open',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'expiresAt': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
      'companyId': _currentUserId,
      'companyName': _currentUserName,
      'companyAvatarUrl': null,
      'applicationCount': 0,
    });
    return _delayed(id);
  }

  Future<int> applyToJob(int jobId) {
    _appliedJobIds.add(jobId);
    final job = _jobs.firstWhere((j) => j['id'] == jobId, orElse: () => {});
    if (job.isNotEmpty) {
      job['applicationCount'] = (job['applicationCount'] as int? ?? 0) + 1;
    }
    return _delayed(_newId());
  }

  Future<List<Map<String, dynamic>>> getMyJobPostings() {
    final mine = _jobs.where((j) => j['companyId'] == _currentUserId).toList();
    // En demo la empresa siempre ve las ofertas sembradas para que la vista
    // de "mis ofertas y postulantes" no aparezca vacía.
    return _delayed(
      mine.isEmpty ? List<Map<String, dynamic>>.from(_jobs) : mine,
    );
  }

  Future<List<Map<String, dynamic>>> getJobApplications(int jobId) {
    final applicants = [101, 104, 102];
    final job = _jobs.firstWhere((j) => j['id'] == jobId, orElse: () => {});
    final count = (job['applicationCount'] as int? ?? 0).clamp(
      0,
      applicants.length,
    );
    return _delayed(
      List.generate(count, (i) {
        final person = _personById(applicants[i])!;
        return {
          'id': 700 + i,
          'createdAt': _iso(Duration(days: i + 1)),
          'cvUrl': null,
          'status': 'Pending',
          'applicant': {
            'id': person['id'],
            'fullName': person['fullName'],
            'email': 'demo${person['id']}@kairos.cl',
            'institution': person['institution'],
            'profilePictureUrl': null,
          },
        };
      }),
    );
  }

  Future<void> updateJobPosting(int jobId, Map<String, dynamic> changes) {
    final job = _jobs.firstWhere((j) => j['id'] == jobId, orElse: () => {});
    if (job.isNotEmpty) job.addAll(changes);
    return _delayed(null);
  }

  Future<void> deleteJobPosting(int jobId) {
    _jobs.removeWhere((j) => j['id'] == jobId);
    return _delayed(null);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  COMPETENCIAS / QUICK MATCH
  // ════════════════════════════════════════════════════════════════════════

  /// Mismas cifras que calcula el backend real, pero sobre los datos en memoria
  /// de la demo: alumnos aprobados, empresas, ofertas abiertas, competencias
  /// más registradas y ofertas por oficio.
  Future<Map<String, dynamic>> getCommunityStats() {
    final studentSkillCounts = <int, int>{};
    for (final person in _people) {
      if (person['role'] != 'student') continue;
      for (final id in (person['skillIds'] as List).cast<int>()) {
        studentSkillCounts[id] = (studentSkillCounts[id] ?? 0) + 1;
      }
    }

    final topSkills =
        _skills
            .where((skill) => studentSkillCounts.containsKey(skill['id']))
            .map(
              (skill) => {
                'id': skill['id'],
                'name': skill['name'],
                'studentCount': studentSkillCounts[skill['id']],
              },
            )
            .toList()
          ..sort(
            (a, b) =>
                (b['studentCount'] as int).compareTo(a['studentCount'] as int),
          );

    // Demanda: cuántas ofertas piden cada competencia, igual que en el backend
    // real desde que las ofertas se vinculan al catálogo.
    final jobSkillCounts = <int, int>{};
    for (final job in _jobs) {
      for (final id in (job['skillIds'] as List<dynamic>? ?? []).cast<int>()) {
        jobSkillCounts[id] = (jobSkillCounts[id] ?? 0) + 1;
      }
    }

    final topDemand =
        _skills
            .where((skill) => jobSkillCounts.containsKey(skill['id']))
            .map(
              (skill) => {
                'id': skill['id'],
                'name': skill['name'],
                'jobCount': jobSkillCounts[skill['id']],
              },
            )
            .toList()
          ..sort(
            (a, b) => (b['jobCount'] as int).compareTo(a['jobCount'] as int),
          );

    return _delayed({
      'students': _people.where((p) => p['role'] == 'student').length,
      'companies': _people.where((p) => p['role'] == 'company').length,
      'activeJobs': _jobs.length,
      'topSkills': topSkills.take(6).toList(),
      'topDemand': topDemand.take(6).toList(),
    });
  }

  Future<List<Map<String, dynamic>>> getSkills() =>
      _delayed(_skills.map((s) => Map<String, dynamic>.from(s)).toList());

  Future<List<int>> getMySkills() => _delayed(_mySkillIds.toList()..sort());

  Future<void> addMySkill(int skillId) {
    _mySkillIds.add(skillId);
    return _delayed(null, 140);
  }

  Future<void> removeMySkill(int skillId) {
    _mySkillIds.remove(skillId);
    return _delayed(null, 140);
  }

  Future<bool> setQuickMatchVisibility(bool visible) {
    _quickMatchVisible = visible;
    return _delayed(visible, 180);
  }

  /// Reproduce el mismo ranking por intersección de competencias que el
  /// backend real (`SearchCandidatesQueryHandler`).
  Future<List<Map<String, dynamic>>> searchCandidates(List<int> skillIds) {
    final searched = _skills
        .where((s) => skillIds.contains(s['id']))
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    if (searched.isEmpty) return _delayed(<Map<String, dynamic>>[]);

    final results = <Map<String, dynamic>>[];
    for (final person in _people) {
      if (person['role'] != 'student') continue;

      final owned = (person['skillIds'] as List).cast<int>();
      final matched = searched.where((s) => owned.contains(s['id'])).toList();
      if (matched.isEmpty) continue;

      final missing = searched.where((s) => !owned.contains(s['id'])).toList();
      results.add({
        'id': person['id'],
        'fullName': person['fullName'],
        'institution': person['institution'],
        'profilePictureUrl': null,
        'matchCount': matched.length,
        'searchedCount': searched.length,
        'matchPercentage': ((matched.length / searched.length) * 100).round(),
        'matchedSkills': matched,
        'missingSkills': missing,
      });
    }

    results.sort((a, b) {
      final byCount = (b['matchCount'] as int).compareTo(
        a['matchCount'] as int,
      );
      return byCount != 0
          ? byCount
          : (a['fullName'] as String).compareTo(b['fullName'] as String);
    });
    return _delayed(results, 450);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  RED DE CONTACTOS
  // ════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getNetworkSuggestions() => _delayed(
    _people
        // Igual que el backend real: quien ya está conectado o tiene una
        // solicitud en curso sale de las sugerencias.
        .where(
          (p) =>
              p['id'] != _currentUserId &&
              !_followingIds.contains(p['id']) &&
              !_sentRequestIds.contains(p['id']) &&
              !_incomingRequests.any((r) => r['id'] == p['id']),
        )
        .map(
          (p) => {
            'id': p['id'],
            'fullName': p['fullName'],
            'role': p['role'],
            'title': p['title'],
            'avatarUrl': '',
            'bio': p['bio'],
            'location': p['institution'],
            'followersCount': p['followers'],
            'connectionStatus': 'none',
          },
        )
        .toList(),
  );

  Future<List<Map<String, dynamic>>> getFollowing() => _delayed(
    _people
        .where((p) => _followingIds.contains(p['id']))
        .map(
          (p) => {
            'id': p['id'],
            'fullName': p['fullName'],
            'role': p['role'],
            'title': p['title'],
            'avatarUrl': '',
          },
        )
        .toList(),
  );

  // ── Conexiones bilaterales ─────────────────────────────────────────────────
  // `_followingIds` guarda ahora las conexiones aceptadas y `_sentRequestIds`
  // las solicitudes enviadas sin responder.

  final Set<int> _sentRequestIds = <int>{};

  /// Solicitudes recibidas de ejemplo, para que la burbuja no salga vacía en la
  /// demo. Se responden como en la aplicación real.
  final List<Map<String, dynamic>> _incomingRequests = [
    {
      'id': 105,
      'fullName': 'Valentina Soto Cárdenas',
      'institution': _liceo,
      'profilePictureUrl': null,
      'bio': 'Modelado 3D y prototipado rápido.',
      'role': 'student',
      'requestedAt': null,
    },
    {
      'id': 106,
      'fullName': 'Ignacio Fuentes Bravo',
      'institution': _liceo,
      'profilePictureUrl': null,
      'bio': 'Robótica y sistemas embebidos.',
      'role': 'student',
      'requestedAt': null,
    },
  ];

  Future<List<Map<String, dynamic>>> getConnectionRequests() =>
      _delayed(List<Map<String, dynamic>>.from(_incomingRequests));

  Future<List<Map<String, dynamic>>> getConnections() => _delayed(
    _people
        .where((p) => _followingIds.contains(p['id']))
        .map(
          (p) => {
            'id': p['id'],
            'fullName': p['fullName'],
            'institution': p['institution'],
            'profilePictureUrl': null,
            'bio': p['bio'],
            'role': p['role'],
            'followersCount': p['followers'],
            'connectionStatus': 'connected',
          },
        )
        .toList(),
  );

  Future<Map<String, dynamic>> requestConnection(int userId) {
    // Si esa persona ya había solicitado, se interpreta como acuerdo.
    final incoming = _incomingRequests.any((r) => r['id'] == userId);
    if (incoming) {
      _incomingRequests.removeWhere((r) => r['id'] == userId);
      _followingIds.add(userId);
      return _delayed({'status': 'connected'});
    }
    _sentRequestIds.add(userId);
    return _delayed({'status': 'pending_sent'});
  }

  Future<void> removeConnection(int userId) {
    _followingIds.remove(userId);
    _sentRequestIds.remove(userId);
    return _delayed(null, 150);
  }

  Future<Map<String, dynamic>> respondToConnectionRequest(
    int userId, {
    required bool accept,
  }) {
    _incomingRequests.removeWhere((r) => r['id'] == userId);
    if (accept) _followingIds.add(userId);
    return _delayed({'status': accept ? 'connected' : 'none'});
  }

  // ════════════════════════════════════════════════════════════════════════
  //  MENSAJERÍA
  // ════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getConversations() =>
      _delayed(List<Map<String, dynamic>>.from(_conversations));

  Future<List<Map<String, dynamic>>> getMessages(int otherUserId) {
    final seeded = <int, List<Map<String, dynamic>>>{
      101: [
        {
          'id': 801,
          'senderId': 201,
          'content':
              'Hola Camila, vimos tu perfil y nos interesan tus competencias.',
          'createdAt': _iso(const Duration(hours: 3)),
        },
        {
          'id': 802,
          'senderId': 101,
          'content': '¡Gracias! Me interesa mucho la oferta.',
          'createdAt': _iso(const Duration(hours: 2)),
        },
      ],
      104: [
        {
          'id': 803,
          'senderId': 104,
          'content': 'Buenas, ¿la práctica es presencial?',
          'createdAt': _iso(const Duration(days: 1)),
        },
      ],
    };
    final list = _messagesByUser.putIfAbsent(
      otherUserId,
      () => List<Map<String, dynamic>>.from(seeded[otherUserId] ?? const []),
    );
    return _delayed(List<Map<String, dynamic>>.from(list));
  }

  Future<Map<String, dynamic>> sendMessage(int receiverId, String content) {
    final message = {
      'id': _newId(),
      'senderId': _currentUserId,
      'receiverId': receiverId,
      'content': content,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    _messagesByUser.putIfAbsent(receiverId, () => []).add(message);

    final existing = _conversations
        .where((c) => c['otherUserId'] == receiverId)
        .toList();
    if (existing.isEmpty) {
      final person = _personById(receiverId);
      _conversations.insert(0, {
        'otherUserId': receiverId,
        'otherUserName': person?['fullName'] ?? 'Usuario',
        'otherUserRole': person?['role'] ?? 'student',
        'otherUserTitle': person?['title'] ?? '',
        'otherUserAvatarUrl': '',
        'lastMessage': content,
        'lastMessageAt': DateTime.now().toUtc().toIso8601String(),
        'hasUnread': false,
      });
    } else {
      existing.first['lastMessage'] = content;
      existing.first['lastMessageAt'] = DateTime.now()
          .toUtc()
          .toIso8601String();
    }
    return _delayed(message, 150);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  DOCUMENTOS PDF
  // ════════════════════════════════════════════════════════════════════════

  /// PDF mínimo válido para que la descarga funcione en el modo demo.
  Future<List<int>> generatePdf(String heading) async {
    final lines = [
      heading,
      _currentUserName,
      'Documento de demostracion - Kairos',
      DateTime.now().toString().substring(0, 16),
    ];
    final content = StringBuffer(
      'BT /F1 16 Tf 60 760 Td (${_escape(lines[0])}) Tj ET\n',
    );
    var y = 730;
    for (final line in lines.skip(1)) {
      content.write('BT /F1 11 Tf 60 $y Td (${_escape(line)}) Tj ET\n');
      y -= 010 + 8;
    }

    final stream = content.toString();
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
          '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
      '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ];

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(buffer.length);
      buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
    final xref = buffer.length;
    buffer.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final offset in offsets) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    buffer.write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xref\n%%EOF',
    );

    return _delayed(latin1.encode(buffer.toString()), 500);
  }

  static String _escape(String value) {
    final ascii = value
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N');
    return ascii
        .replaceAll('\\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }
}
