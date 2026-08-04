import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import 'demo_backend.dart';
import 'demo_interceptor.dart';

// Se reexporta para no romper los archivos que ya importaban kDemoMode desde acá.
export '../config.dart' show kDemoMode;

class ApiClient {
  static const _baseUrl     = kApiUrl;
  static const _tokenKey    = 'auth_token';
  static const _profileKey  = 'auth_profile';

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
    ));

    if (kDemoMode) _dio.interceptors.add(DemoInterceptor());

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await _storage.read(key: _tokenKey)
              .timeout(const Duration(seconds: 3));
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {
          // flutter_secure_storage puede fallar en web — continuar sin token
        }
        return handler.next(options);
      },
      onError: (error, handler) => handler.next(error),
    ));
  }

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> saveProfile(Map<String, String?> profile) async {
    try {
      final encoded = profile.entries
          .where((e) => e.value != null)
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value!)}')
          .join('&');
      await _storage.write(key: _profileKey, value: encoded)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<Map<String, String>?> loadProfile() async {
    try {
      final raw = await _storage.read(key: _profileKey)
          .timeout(const Duration(seconds: 3));
      if (raw == null || raw.isEmpty) return null;
      return Map.fromEntries(raw.split('&').map((kv) {
        final parts = kv.split('=');
        return MapEntry(
          Uri.decodeComponent(parts[0]),
          parts.length > 1 ? Uri.decodeComponent(parts.sublist(1).join('=')) : '',
        );
      }));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearToken() async {
    try {
      await Future.wait([
        _storage.delete(key: _tokenKey).timeout(const Duration(seconds: 3)),
        _storage.delete(key: _profileKey).timeout(const Duration(seconds: 3)),
      ]);
    } catch (_) {}
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Inicio de sesión del modo demo: no valida credenciales, solo toma el rol
  /// elegido por el tester. El rol staff no se ofrece a propósito.
  Future<Map<String, dynamic>> demoLogin({
    required String role,
    required String name,
  }) => DemoBackend.instance.login('demo@kairos.cl', role, name);

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String? institution,
    String role = 'student',
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
      'fullName': fullName,
      'institution': institution,
      'role': role,
    });
    return response.data as Map<String, dynamic>;
  }

  // ── Feed / Posts ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getFeed({int page = 1, int pageSize = 20}) async {
    final response = await _dio.get('/posts/feed', queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<int> createPost({
    required String content,
    String postType = 'general',
    String? imageUrl,
    String? eventDate,
  }) async {
    final response = await _dio.post('/posts', data: {
      'content': content,
      'postType': postType,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (eventDate != null) 'eventDate': eventDate,
    });
    return response.data as int;
  }

  /// Toggle like on a post. Returns the new likes count.
  Future<Map<String, dynamic>> toggleLike(int postId) async {
    final response = await _dio.post('/posts/$postId/like');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getComments(int postId,
      {int page = 1, int pageSize = 20}) async {
    final response = await _dio.get(
      '/posts/$postId/comments',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> addComment(int postId, String content) async {
    final response = await _dio.post('/posts/$postId/comments', data: {
      'content': content,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> deletePost(int postId) async {
    await _dio.delete('/posts/$postId');
  }

  Future<void> updatePost(int postId, String content) async {
    await _dio.put('/posts/$postId', data: {'content': content});
  }

  // ── Jobs ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getJobs({
    String? search,
    String status = 'Open',
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get('/jobs', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      'status': status,
      'page': page,
      'pageSize': pageSize,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<int> createJobPosting({
    required String title,
    required String description,
    String? location,
    String? imageUrl,
    DateTime? expiresAt,
  }) async {
    final response = await _dio.post('/jobs', data: {
      'title': title,
      'description': description,
      if (location != null) 'location': location,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
    });
    return response.data as int;
  }

  Future<int> applyToJob(int jobId, {String? cvUrl}) async {
    final response = await _dio.post('/jobs/$jobId/apply', data: {
      if (cvUrl != null) 'cvUrl': cvUrl,
    });
    return response.data as int;
  }

  // ── Skills / Quick Match ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSkills() async {
    final response = await _dio.get('/skills');
    return (response.data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> searchCandidates(List<int> skillIds) async {
    final response = await _dio.get('/skills/candidates', queryParameters: {
      'skillIds': skillIds.join(','),
    });
    return (response.data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<bool> setQuickMatchVisibility(bool visible) async {
    final response = await _dio.put('/skills/me/visibility', data: {
      'visible': visible,
    });
    return response.data['visible'] as bool;
  }

  Future<List<int>> getMySkills() async {
    final response = await _dio.get('/skills/me');
    return (response.data as List<dynamic>).cast<int>();
  }

  Future<void> addMySkill(int skillId) async {
    await _dio.post('/skills/me/$skillId');
  }

  Future<void> removeMySkill(int skillId) async {
    await _dio.delete('/skills/me/$skillId');
  }

  /// Company-only: get the current Quick Match contact message template.
  /// Returns `{ template: String, isDefault: bool }`.
  Future<Map<String, dynamic>> getCompanyMessageTemplate() async {
    final response = await _dio.get('/skills/company/message');
    return response.data as Map<String, dynamic>;
  }

  /// Company-only: update the Quick Match contact message template.
  /// Passing an empty string resets it to the system default.
  /// Returns `{ template: String, isDefault: bool }`.
  Future<Map<String, dynamic>> setCompanyMessageTemplate(String template) async {
    final response = await _dio.put('/skills/company/message', data: {
      'template': template,
    });
    return response.data as Map<String, dynamic>;
  }

  // ── Network ──────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getNetworkSuggestions(
      {int page = 1, int pageSize = 20}) async {
    final response = await _dio.get('/network/suggestions', queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    return response.data as List<dynamic>;
  }

  Future<void> followUser(int userId) async {
    await _dio.post('/network/$userId/follow');
  }

  Future<void> unfollowUser(int userId) async {
    await _dio.delete('/network/$userId/follow');
  }

  Future<List<dynamic>> getFollowing() async {
    final response = await _dio.get('/network/following');
    return response.data as List<dynamic>;
  }

  // ── Chat ─────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getConversations() async {
    final response = await _dio.get('/chat/conversations');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getMessages(int otherUserId,
      {int page = 1, int pageSize = 40}) async {
    final response = await _dio.get(
      '/chat/messages/$otherUserId',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> sendMessage(
      int receiverId, String content) async {
    final response = await _dio
        .post('/chat/messages/$receiverId', data: {'content': content});
    return response.data as Map<String, dynamic>;
  }

  // ── Storage ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadFile(
      String filePath, String contentType) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath,
          filename: filePath.split('/').last),
    });
    final response = await _dio.post(
      '/storage/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Upload an image from XFile (works on web and mobile).
  Future<Map<String, dynamic>> uploadImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final filename = image.name.isNotEmpty ? image.name : image.path.split('/').last;
    final ext = filename.split('.').last.toLowerCase();
    final subtype = switch (ext) {
      'png'  => 'png',
      'webp' => 'webp',
      'gif'  => 'gif',
      _      => 'jpeg',
    };

    // En modo demo no hay servidor de archivos: la imagen se incrusta como
    // data URL para que el usuario vea exactamente la que eligió.
    if (kDemoMode) {
      return {'cdnUrl': 'data:image/$subtype;base64,${base64Encode(bytes)}'};
    }

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType('image', subtype),
      ),
    });
    final response = await _dio.post(
      '/storage/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Reports ─────────────────────────────────────────────────────────────────

  Future<List<int>> downloadReport({int? month, int? year}) async {
    if (kDemoMode) {
      return DemoBackend.instance.generatePdf('Reporte mensual de actividad');
    }
    final response = await _dio.get<List<int>>(
      '/reports/me',
      queryParameters: {
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }

  // ── Curriculum ───────────────────────────────────────────────────────────────

  /// Generate and download a full CV PDF built from the user's activity history.
  Future<List<int>> downloadCurriculum() async {
    if (kDemoMode) {
      return DemoBackend.instance.generatePdf('Curriculum Vitae');
    }
    final response = await _dio.get<List<int>>(
      '/curriculum/me',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }

  // ── Staff ────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getRegistrationRequests() async {
    final response = await _dio.get('/staff/registration-requests');
    return response.data as List<dynamic>;
  }

  Future<void> approveUser(int userId) async {
    await _dio.post('/staff/users/$userId/approve');
  }

  Future<void> rejectUser(int userId) async {
    await _dio.post('/staff/users/$userId/reject');
  }

  Future<void> deleteUser(int userId) async {
    await _dio.delete('/staff/users/$userId');
  }

  Future<List<dynamic>> getAllUsers() async {
    final response = await _dio.get('/staff/users');
    return response.data as List<dynamic>;
  }

  // ── Jobs (company management) ────────────────────────────────────────────────

  Future<List<dynamic>> getMyJobPostings() async {
    final response = await _dio.get('/jobs/my-postings');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getJobApplications(int jobId) async {
    final response = await _dio.get('/jobs/$jobId/applications');
    return response.data as List<dynamic>;
  }

  Future<void> updateJobPosting({
    required int jobId,
    required String title,
    required String description,
    String? location,
    String? imageUrl,
  }) async {
    await _dio.put('/jobs/$jobId', data: {
      'title': title,
      'description': description,
      if (location != null && location.isNotEmpty) 'location': location,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
  }

  Future<void> deleteJobPosting(int jobId) async {
    await _dio.delete('/jobs/$jobId');
  }
}
