import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/analytics/analytics.dart';
import '../../core/api/api_client.dart';
import '../../features/home/data/models/post_model.dart';
import '../theme/app_colors.dart';
import '../theme/kairos_palette.dart';
import 'k_card.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.currentUserId = '',
    this.currentUserRole = '',
    this.onDeleted,
    this.onEdited,
  });

  final PostModel post;
  final String currentUserId;
  final String currentUserRole;
  final VoidCallback? onDeleted;
  final void Function(String newContent)? onEdited;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _liked;
  late int _likes;
  late bool _isExpanded;
  bool _liking = false;

  // Comments
  bool _showComments = false;
  bool _loadingComments = false;
  final List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _submittingComment = false;

  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _liked = false;
    _likes = widget.post.likes;
    _isExpanded = false;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    setState(() {
      _liking = true;
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    Analytics.postLike(_liked);
    try {
      final postId = int.tryParse(widget.post.id);
      if (postId != null) {
        final result = await _api.toggleLike(postId);
        if (mounted) {
          setState(() => _likes = result['likesCount'] as int? ?? _likes);
        }
      }
    } catch (_) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likes += _liked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  void _toggleExpanded() => setState(() => _isExpanded = !_isExpanded);

  void _sharePost() {
    Analytics.postShare();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace de la publicación copiado.')),
    );
  }

  Future<void> _toggleComments() async {
    setState(() => _showComments = !_showComments);
    if (_showComments && _comments.isEmpty) {
      await _loadComments();
    }
  }

  Future<void> _loadComments() async {
    final postId = int.tryParse(widget.post.id);
    if (postId == null) return;
    setState(() => _loadingComments = true);
    try {
      final result = await _api.getComments(postId);
      if (mounted) {
        setState(
          () => _comments
            ..clear()
            ..addAll(result.cast<Map<String, dynamic>>()),
        );
      }
    } catch (_) {
      // Silently ignore — comments stay empty
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta publicación? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final postId = int.tryParse(widget.post.id);
      if (postId != null) await _api.deletePost(postId);
      widget.onDeleted?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar la publicación.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showEditDialog() {
    final ctrl = TextEditingController(text: widget.post.content);
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Editar publicación'),
          content: SizedBox(
            width: 480,
            child: TextField(
              controller: ctrl,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Contenido de la publicación',
                hintText: 'Escribe algo...',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final newContent = ctrl.text.trim();
                      if (newContent.isEmpty) return;
                      setInner(() => saving = true);
                      try {
                        final postId = int.tryParse(widget.post.id);
                        if (postId != null) {
                          await _api.updatePost(postId, newContent);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        widget.onEdited?.call(newContent);
                      } catch (_) {
                        setInner(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No se pudo editar la publicación.',
                              ),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final postId = int.tryParse(widget.post.id);
    if (postId == null) return;

    setState(() => _submittingComment = true);
    try {
      final dto = await _api.addComment(postId, text);
      Analytics.postComment();
      _commentController.clear();
      if (mounted) {
        setState(() {
          _comments.add(dto);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo agregar el comentario.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingComment = false);
    }
  }

  bool _shouldUseSquareMedia(String? url) {
    if (url == null || url.isEmpty) return false;
    final normalized = url.toLowerCase();
    if (normalized.contains('1x1') ||
        normalized.contains('1:1') ||
        normalized.contains('square')) {
      return true;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final widthRaw = uri.queryParameters['w'] ?? uri.queryParameters['width'];
    final heightRaw = uri.queryParameters['h'] ?? uri.queryParameters['height'];
    final width = int.tryParse(widthRaw ?? '');
    final height = int.tryParse(heightRaw ?? '');
    return width != null && height != null && width == height;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final authorAvatar = post.author.avatarUrl.trim();
    final imageUrl = post.imageUrl?.trim();
    final content = post.content.trim();
    final canCollapseContent = content.length > 180;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCardWidth = switch (constraints.maxWidth) {
          >= 1200 => 620.0,
          >= 900 => 580.0,
          >= 700 => 540.0,
          _ => constraints.maxWidth,
        };
        final cardWidth = math.min(constraints.maxWidth, maxCardWidth);
        final mediaAspectRatio = _shouldUseSquareMedia(imageUrl) ? 1.0 : 3 / 4;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: cardWidth,
            child: KCard(
              borderColor: post.isEvent
                  ? KairosPalette.primary.withValues(alpha: 0.4)
                  : KairosPalette.border,
              gradient: post.isEvent
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x1A0F766E), Colors.white],
                    )
                  : null,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.isEvent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: KairosPalette.primary,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(17),
                          topRight: Radius.circular(17),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Evento  ${post.eventDate ?? ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: CircleAvatar(
                            radius: 22,
                            backgroundImage: authorAvatar.isNotEmpty
                                ? NetworkImage(authorAvatar)
                                : null,
                            child: authorAvatar.isEmpty
                                ? const Icon(Icons.person_rounded)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.author.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                post.author.title,
                                style: const TextStyle(
                                  color: KairosPalette.secondary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                post.timestamp,
                                style: const TextStyle(
                                  color: KairosPalette.secondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _PostMenu(
                          canEdit:
                              widget.currentUserId.isNotEmpty &&
                              widget.currentUserId == post.author.id,
                          canDelete:
                              widget.currentUserId.isNotEmpty &&
                              (widget.currentUserId == post.author.id ||
                                  widget.currentUserRole == 'staff'),
                          onEdit: _showEditDialog,
                          onDelete: _confirmDelete,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content,
                          style: const TextStyle(height: 1.4),
                          maxLines: _isExpanded ? null : 3,
                          overflow: _isExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                        if (canCollapseContent)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: _toggleExpanded,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                minimumSize: const Size(48, 48),
                                tapTargetSize: MaterialTapTargetSize.padded,
                                foregroundColor: KairosPalette.primary,
                              ),
                              child: Text(
                                _isExpanded ? 'Ver menos' : 'Ver más',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: mediaAspectRatio,
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            semanticLabel: post.resolvedImageAltText,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: KairosPalette.border),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 520;
                        if (isCompact) {
                          return Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                '$_likes Me gusta',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${post.comments + _comments.length} Comentarios',
                              ),
                              Text('${post.shares} Compartidos'),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Text(
                              '$_likes Me gusta',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${post.comments + _comments.length} Comentarios',
                            ),
                            const SizedBox(width: 12),
                            Text('${post.shares} Compartidos'),
                          ],
                        );
                      },
                    ),
                  ),
                  Row(
                    children: [
                      _ActionButton(
                        icon: _liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: 'Me gusta',
                        color: _liked
                            ? KairosPalette.accent
                            : KairosPalette.secondary,
                        onTap: _toggleLike,
                      ),
                      _ActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Comentar',
                        color: _showComments
                            ? KairosPalette.primary
                            : KairosPalette.secondary,
                        onTap: _toggleComments,
                      ),
                      _ActionButton(
                        icon: Icons.share_rounded,
                        label: 'Compartir',
                        color: KairosPalette.secondary,
                        onTap: _sharePost,
                      ),
                    ],
                  ),

                  // ── Comment section ─────────────────────────────────────────
                  if (_showComments)
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: KairosPalette.border),
                        ),
                        color: Color(0x060F766E),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loadingComments)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else
                            ..._comments.map((c) => _commentTile(c)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  decoration: InputDecoration(
                                    labelText: 'Comentario',
                                    hintText: 'Escribe un comentario...',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: const BorderSide(
                                        color: KairosPalette.border,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: const BorderSide(
                                        color: KairosPalette.border,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: const BorderSide(
                                        color: KairosPalette.primary,
                                      ),
                                    ),
                                  ),
                                  onSubmitted: (_) => _submitComment(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: _submittingComment
                                    ? 'Enviando comentario'
                                    : 'Enviar comentario',
                                onPressed: _submittingComment
                                    ? null
                                    : _submitComment,
                                icon: _submittingComment
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.send_rounded,
                                        color: KairosPalette.primary,
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _commentTile(Map<String, dynamic> comment) {
    final avatar = (comment['authorAvatarUrl'] as String? ?? '').trim();
    final name = comment['authorName'] as String? ?? 'Usuario';
    final content = comment['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(comment['createdAt'] as String? ?? '');
    final time = createdAt != null
        ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 16,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? const Icon(Icons.person_rounded, size: 16)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KairosPalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: KairosPalette.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(content, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostMenu extends StatelessWidget {
  const _PostMenu({
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (!canEdit && !canDelete) {
      return const SizedBox(width: 40);
    }
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_horiz_rounded,
        color: KairosPalette.secondary,
      ),
      tooltip: 'Más opciones para la publicación',
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        if (canEdit)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                ExcludeSemantics(child: Icon(Icons.edit_rounded, size: 18)),
                SizedBox(width: 10),
                Text('Editar'),
              ],
            ),
          ),
        if (canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.delete_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                ),
                SizedBox(width: 10),
                Text('Eliminar', style: TextStyle(color: AppColors.danger)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          container: true,
          button: true,
          enabled: true,
          label: label,
          onTap: onTap,
          child: ExcludeSemantics(
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
