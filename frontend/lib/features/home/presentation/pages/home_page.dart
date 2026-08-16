import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/analytics/analytics.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/kairos_palette.dart';
import '../../../../core/widgets/k_card.dart';
import '../../../../core/widgets/post_card.dart';
import '../../../home/data/models/post_model.dart';
import '../../../staff/presentation/pages/registration_requests_page.dart';
import '../../../staff/presentation/pages/skill_catalog_page.dart';
import '../../../staff/presentation/pages/staff_management_page.dart';
import '../../../staff/presentation/pages/user_management_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.currentUser, required this.role});

  final UserProfile currentUser;
  final UserRole role;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _postController = TextEditingController();
  final FocusNode _postFocusNode = FocusNode();
  // Descripción de la imagen adjunta. Va vacío por defecto: si el autor no la
  // escribe, la imagen se publica como decorativa en vez de heredar el texto
  // del post como texto alternativo.
  final TextEditingController _imageAltController = TextEditingController();

  final _api = ApiClient();
  final _picker = ImagePicker();
  List<PostModel> _posts = [];
  bool _feedLoading = true;
  String? _feedError;
  bool _publishing = false;
  XFile? _selectedImage;
  bool _uploadingImage = false;
  String? _uploadedImageUrl;

  // Cifras reales de la comunidad para las tarjetas laterales.
  /// Oferta de talento: competencias ordenadas por cuántos alumnos las tienen.
  List<Map<String, dynamic>> _topSkills = [];

  /// Demanda: competencias ordenadas por cuántas ofertas abiertas las piden.
  List<Map<String, dynamic>> _topDemand = [];
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _api.getCommunityStats();
      if (!mounted) return;
      setState(() {
        _topSkills = (stats['topSkills'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _topDemand = (stats['topDemand'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
      });
    } catch (_) {
      // Las tarjetas laterales son accesorias: si fallan se muestran vacías,
      // que es preferible a inventar números o a tumbar el feed entero.
      if (mounted) {
        setState(() {
          _topSkills = [];
          _topDemand = [];
        });
      }
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  static String _offersLabel(int count) =>
      count == 1 ? '1 oferta' : '$count ofertas';

  @override
  void dispose() {
    _postFocusNode.dispose();
    _postController.dispose();
    _imageAltController.dispose();

    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _feedLoading = true;
      _feedError = null;
    });
    try {
      final data = await _api.getFeed();
      final items = (data['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(PostModel.fromJson)
          .toList();
      if (mounted) setState(() => _posts = items);
    } catch (_) {
      // Antes se rellenaba el feed con publicaciones de ejemplo. En producción
      // eso es peor que un error: el usuario ve contenido inventado, atribuido a
      // personas que no existen, sin ninguna señal de que algo falló.
      if (mounted) {
        setState(() {
          _posts = [];
          _feedError =
              'No se pudieron cargar las publicaciones. '
              'Revisa tu conexión y vuelve a intentarlo.';
        });
      }
    } finally {
      if (mounted) setState(() => _feedLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    setState(() {
      _selectedImage = image;
      _uploadedImageUrl = null;
      _imageAltController.clear();
      _uploadingImage = true;
    });
    try {
      final result = await _api.uploadImage(image);
      if (mounted) {
        setState(() => _uploadedImageUrl = result['cdnUrl'] as String?);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _selectedImage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo subir la imagen.'),
            backgroundColor: KairosPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  /// Descripción de la imagen, o null si el autor la dejó en blanco. Null se
  /// publica como imagen decorativa; nunca se sustituye por el texto del post.
  String? _imageAltText() {
    if (_uploadedImageUrl == null) return null;
    final alt = _imageAltController.text.trim();
    return alt.isEmpty ? null : alt;
  }

  Future<void> _publishPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty && _uploadedImageUrl == null) return;

    setState(() => _publishing = true);
    try {
      await _api.createPost(
        content: text,
        postType: 'general',
        imageUrl: _uploadedImageUrl,
        imageAltText: _imageAltText(),
      );
      Analytics.postCreate('general');
      _postController.clear();
      _postFocusNode.unfocus();
      setState(() {
        _selectedImage = null;
        _uploadedImageUrl = null;
        _imageAltController.clear();
      });
      await _loadFeed();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo publicar. Intenta de nuevo.'),
            backgroundColor: KairosPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _promptEventDate() async {
    final text = _postController.text.trim();
    if (text.isEmpty && _uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Escribe una descripción o agrega una imagen para el evento.',
          ),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Fecha del evento',
    );
    if (picked == null) return;

    final eventDate =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    await _publishEventPost(eventDate);
  }

  Future<void> _publishEventPost(String eventDate) async {
    final text = _postController.text.trim();
    if (text.isEmpty && _uploadedImageUrl == null) return;

    setState(() => _publishing = true);
    try {
      await _api.createPost(
        content: text,
        postType: 'event',
        imageUrl: _uploadedImageUrl,
        imageAltText: _imageAltText(),
        eventDate: eventDate,
      );
      Analytics.postCreate('event');
      _postController.clear();
      _postFocusNode.unfocus();
      setState(() {
        _selectedImage = null;
        _uploadedImageUrl = null;
        _imageAltController.clear();
      });
      await _loadFeed();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo publicar el evento. Intenta de nuevo.'),
            backgroundColor: KairosPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width > 1240;
    final canCreateEvent =
        widget.role == UserRole.staff || widget.role == UserRole.company;
    final canCreateJobOffer = widget.role == UserRole.company;

    if (desktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 280, child: _leftSidebar()),
            const SizedBox(width: 16),
            Expanded(
              child: _mainContent(
                canCreateEvent: canCreateEvent,
                canCreateJobOffer: canCreateJobOffer,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 300,
              child: _rightSidebar(canCreateJobOffer: canCreateJobOffer),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _leftSidebar(),
          const SizedBox(height: 12),
          _mainContent(
            canCreateEvent: canCreateEvent,
            canCreateJobOffer: canCreateJobOffer,
          ),
          const SizedBox(height: 12),
          _rightSidebar(canCreateJobOffer: canCreateJobOffer),
        ],
      ),
    );
  }

  Widget _leftSidebar() {
    return Column(
      children: [
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up_rounded, color: KairosPalette.primary),
                  SizedBox(width: 8),
                  // Antes decía "En demanda" sobre una lista fija de cinco
                  // competencias. El título ahora describe lo que el número
                  // realmente mide: cuántos alumnos declararon cada una.
                  Text(
                    'Competencias más registradas',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_statsLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else if (_topSkills.isEmpty)
                const Text(
                  'Todavía ningún alumno ha registrado competencias.',
                  style: TextStyle(color: KairosPalette.mutedForeground),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _topSkills
                      .map(
                        (skill) => Chip(
                          label: Text(
                            '${skill['name']} · ${skill['studentCount']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          side: BorderSide.none,
                          backgroundColor: KairosPalette.muted,
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mainContent({
    required bool canCreateEvent,
    required bool canCreateJobOffer,
  }) {
    final isStaff = widget.role == UserRole.staff;
    final currentAvatar = widget.currentUser.avatarUrl.trim();
    return Column(
      children: [
        // ── Banner de gestión para staff ─────────────────────────────────────
        if (isStaff)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: KCard(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x1A0F766E), Color(0xFFE8F3EF)],
              ),
              borderColor: KairosPalette.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: KairosPalette.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.manage_accounts_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Panel de Gestión',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Crea cuentas de alumnos o staff desde un CSV.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegistrationRequestsPage(),
                          ),
                        ),
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Solicitudes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KairosPalette.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const UserManagementPage(),
                          ),
                        ),
                        icon: const Icon(
                          Icons.manage_accounts_rounded,
                          size: 18,
                        ),
                        label: const Text('Usuarios'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KairosPalette.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StaffManagementPage(),
                          ),
                        ),
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Importar CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KairosPalette.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SkillCatalogPage(),
                          ),
                        ),
                        icon: const Icon(Icons.checklist_rounded, size: 18),
                        label: const Text('Competencias'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KairosPalette.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // ── Post composer ─────────────────────────────────────────────────────
        KCard(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: currentAvatar.isNotEmpty
                        ? NetworkImage(currentAvatar)
                        : null,
                    child: currentAvatar.isEmpty
                        ? const Icon(Icons.person_rounded)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _postController,
                          focusNode: _postFocusNode,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(1000),
                          ],
                          minLines: 1,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            labelText: 'Contenido de la publicación',
                            hintText: '¿Qué quieres compartir hoy?',
                            filled: true,
                            fillColor: KairosPalette.background,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: KairosPalette.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: KairosPalette.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: KairosPalette.primary,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        ListenableBuilder(
                          listenable: _postFocusNode,
                          builder: (context, _) {
                            if (!_postFocusNode.hasFocus) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              children: [
                                const SizedBox(height: 4),
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _postController,
                                  builder: (context, value, _) {
                                    final count = value.text.characters.length;
                                    final atLimit = count >= 1000;
                                    return Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '$count/1000',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: atLimit
                                              ? KairosPalette.danger
                                              : KairosPalette.secondary,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_selectedImage != null) ...[
                const SizedBox(height: 8),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _uploadingImage
                          ? Container(
                              height: 120,
                              color: KairosPalette.muted,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Image.network(
                              _uploadedImageUrl ?? '',
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              semanticLabel:
                                  'Imagen seleccionada para la publicación',
                              errorBuilder: (_, __, ___) => Container(
                                height: 120,
                                color: KairosPalette.muted,
                                child: const Icon(Icons.image_rounded),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Quitar imagen seleccionada',
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() {
                            _selectedImage = null;
                            _uploadedImageUrl = null;
                            _imageAltController.clear();
                          }),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _imageAltController,
                  maxLength: 300,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Describe la imagen',
                    hintText:
                        'Ej: taller de mecánica con tres alumnos soldando',
                    helperText:
                        'Se lee en voz alta a quien no puede ver la imagen. '
                        'Déjalo vacío si la imagen es solo decorativa.',
                    helperMaxLines: 2,
                    counterText: '',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _buildComposerActions(
                canCreateEvent: canCreateEvent,
                canCreateJobOffer: canCreateJobOffer,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Feed ──────────────────────────────────────────────────────────────
        if (_feedLoading)
          Semantics(
            liveRegion: true,
            container: true,
            label: 'Cargando publicaciones',
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_feedError != null)
          Semantics(
            liveRegion: true,
            container: true,
            label: _feedError!,
            child: KCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: KairosPalette.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_feedError!)),
                    TextButton(
                      onPressed: _loadFeed,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_posts.isEmpty)
          const KCard(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No hay publicaciones aún.')),
            ),
          )
        else
          ..._posts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(
                post: post,
                currentUserId: widget.currentUser.id,
                currentUserRole: widget.currentUser.role.name,
                onDeleted: () => setState(() => _posts.remove(post)),
                onEdited: (newContent) {
                  setState(() {
                    final idx = _posts.indexOf(post);
                    if (idx != -1)
                      _posts[idx] = post.copyWith(content: newContent);
                  });
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _rightSidebar({required bool canCreateJobOffer}) {
    return Column(
      children: [
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_rounded,
                    color: KairosPalette.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Consejos del día',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _tip('Completa tu perfil para recibir más visitas.'),
              _tip('Agrega certificaciones y proyectos para destacar.'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.build_rounded, color: KairosPalette.primary),
                  SizedBox(width: 8),
                  Text(
                    'Lo que más piden las empresas',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Esta tarjeta listaba cinco oficios fijos con un número calculado
              // como `120 - posición * 15`. Ahora cuenta cuántas ofertas abiertas
              // solicitan cada competencia, que es demanda medida, no estimada.
              if (_statsLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else if (_topDemand.isEmpty)
                const Text(
                  'Ninguna oferta abierta indica todavía qué competencias busca.',
                  style: TextStyle(color: KairosPalette.mutedForeground),
                )
              else
                ..._topDemand.map(
                  (skill) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(skill['name'] as String? ?? ''),
                    trailing: Text(
                      _offersLabel(skill['jobCount'] as int? ?? 0),
                      style: const TextStyle(
                        color: KairosPalette.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (canCreateJobOffer) ...[
          const SizedBox(height: 12),
          KCard(
            gradient: const LinearGradient(
              colors: [Color(0x1A00B5AD), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderColor: KairosPalette.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Publica una oferta',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 6),
                const Text('Encuentra talento técnico para tu empresa.'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KairosPalette.accent,
                    ),
                    onPressed: () => _showCreateOfferDialog(context),
                    child: const Text('Crear oferta laboral'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _tip(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: KairosPalette.muted,
      ),
      child: Text(text),
    );
  }

  Widget _buildComposerActions({
    required bool canCreateEvent,
    required bool canCreateJobOffer,
  }) {
    final actions = <Widget>[
      _mediaAction(),
      if (canCreateEvent)
        _ghostAction(
          Icons.calendar_month_rounded,
          'Evento',
          onPressed: _promptEventDate,
        ),
      if (canCreateJobOffer)
        _accentAction(Icons.work_rounded, 'Oferta laboral'),
      _publishAction(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  actions[i],
                  if (i != actions.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Medidas comunes de los botones del compositor.
  ///
  /// "Media" y "Publicar" tenían un ancho fijo de 116 y "Evento" se ajustaba a
  /// su contenido, así que los tres salían de distinto tamaño. Ahora comparten
  /// alto, relleno y radio, y cada uno mide lo que necesita su texto — que es
  /// además lo que aguanta el escalado de texto al 200 %.
  static const double _composerButtonHeight = 48;
  static const EdgeInsets _composerButtonPadding = EdgeInsets.symmetric(
    horizontal: 16,
  );
  static final BorderRadius _composerButtonRadius = BorderRadius.circular(12);

  Widget _mediaAction() {
    return OutlinedButton.icon(
      onPressed: _uploadingImage ? null : _pickImage,
      icon: const Icon(Icons.image_rounded, size: 16),
      label: const Text('Media'),
      style: OutlinedButton.styleFrom(
        foregroundColor: KairosPalette.secondary,
        minimumSize: const Size(0, _composerButtonHeight),
        padding: _composerButtonPadding,
        shape: RoundedRectangleBorder(borderRadius: _composerButtonRadius),
        side: const BorderSide(color: KairosPalette.border),
      ),
    );
  }

  Widget _ghostAction(
    IconData icon,
    String label, {
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: KairosPalette.secondary,
        minimumSize: const Size(0, _composerButtonHeight),
        padding: _composerButtonPadding,
        shape: RoundedRectangleBorder(borderRadius: _composerButtonRadius),
        side: const BorderSide(color: KairosPalette.border),
      ),
    );
  }

  Widget _accentAction(IconData icon, String label) {
    return ElevatedButton.icon(
      onPressed: () => _showCreateOfferDialog(context),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, _composerButtonHeight),
        padding: _composerButtonPadding,
        shape: RoundedRectangleBorder(borderRadius: _composerButtonRadius),
        backgroundColor: KairosPalette.accent,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showCreateOfferDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text(
            'Publicar oferta laboral',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cargo / título *',
                      hintText: 'Ej: Técnico en Automatización',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Campo requerido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción *',
                      hintText: 'Describe las responsabilidades del cargo',
                    ),
                    maxLines: 3,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Campo requerido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ubicación',
                      hintText: 'Ej: Santiago, Chile',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setInner(() => submitting = true);
                      try {
                        await _api.createJobPosting(
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          location: locationCtrl.text.trim().isEmpty
                              ? null
                              : locationCtrl.text.trim(),
                        );
                        Analytics.jobCreate();
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Oferta publicada exitosamente.'),
                              backgroundColor: KairosPalette.success,
                            ),
                          );
                        }
                      } catch (_) {
                        setInner(() => submitting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo publicar la oferta.'),
                              backgroundColor: KairosPalette.danger,
                            ),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Publicar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _publishAction() {
    return SizedBox(
      height: _composerButtonHeight,
      child: ElevatedButton(
        onPressed: _publishing ? null : _publishPost,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, _composerButtonHeight),
          shape: RoundedRectangleBorder(borderRadius: _composerButtonRadius),
          padding: _composerButtonPadding,
          elevation: 4,
          shadowColor: KairosPalette.primary.withValues(alpha: 0.35),
        ),
        child: _publishing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Publicar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
