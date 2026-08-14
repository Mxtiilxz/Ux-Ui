import '../../../../core/models/user_profile.dart';

class PostModel {
  const PostModel({
    required this.id,
    required this.author,
    required this.content,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.timestamp,
    this.imageUrl,
    this.imageAltText,
    this.isEvent = false,
    this.eventDate,
  });

  final String id;
  final UserProfile author;
  final String content;
  final String? imageUrl;

  /// API-provided alternative text for the post image, when available.
  final String? imageAltText;
  final int likes;
  final int comments;
  final int shares;
  final String timestamp;
  final bool isEvent;
  final String? eventDate;

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['authorRole'] as String? ?? 'student').toLowerCase();
    final role = switch (roleStr) {
      'staff' => UserRole.staff,
      'company' => UserRole.company,
      'alumni' => UserRole.alumni,
      _ => UserRole.student,
    };
    final titleByRole = switch (roleStr) {
      'staff' => 'Staff del Liceo',
      'company' => 'Empresa',
      'alumni' => 'Egresado',
      _ => 'Estudiante',
    };

    final author = UserProfile(
      id: json['authorId'].toString(),
      name: json['authorName'] as String? ?? 'Usuario',
      role: role,
      title: titleByRole,
      avatarUrl: json['authorProfilePictureUrl'] as String? ?? '',
      skills: const [],
      bio: '',
      location: '',
      connections: 0,
    );

    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final timestamp = createdAt != null ? _formatRelative(createdAt) : '';

    return PostModel(
      id: json['id'].toString(),
      author: author,
      content: json['content'] as String? ?? '',
      likes: json['likesCount'] as int? ?? 0,
      comments: json['commentsCount'] as int? ?? 0,
      shares: 0,
      timestamp: timestamp,
      imageUrl: json['imageUrl'] as String?,
      imageAltText:
          (json['imageAltText'] ?? json['imageAlt'] ?? json['imageDescription'])
              as String?,
      isEvent: (json['postType'] as String? ?? '').toLowerCase() == 'event',
      eventDate: json['eventDate'] as String?,
    );
  }

  PostModel copyWith({
    int? likes,
    int? comments,
    String? content,
    String? imageAltText,
  }) {
    return PostModel(
      id: id,
      author: author,
      content: content ?? this.content,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares,
      timestamp: timestamp,
      imageUrl: imageUrl,
      imageAltText: imageAltText ?? this.imageAltText,
      isEvent: isEvent,
      eventDate: eventDate,
    );
  }

  /// Etiqueta que debe anunciar un lector de pantalla para la imagen, o `null`
  /// si la imagen es decorativa y hay que excluirla del árbol de semántica.
  ///
  /// Deliberadamente no se rellena con el cuerpo de la publicación: ese texto
  /// ya lo lee el lector justo encima, y repetirlo como descripción de la
  /// imagen es ruido, no información (WCAG 1.1.1). Cuando el autor no describe
  /// la imagen, lo correcto es callarla.
  String? get imageSemanticLabel {
    final provided = imageAltText?.trim();
    if (provided == null || provided.isEmpty) return null;
    return provided;
  }

  static String _formatRelative(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
