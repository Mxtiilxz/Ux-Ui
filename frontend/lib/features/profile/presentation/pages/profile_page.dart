import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/analytics/analytics.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/kairos_palette.dart';
import '../../../../core/utils/file_downloader.dart';
import '../../../../core/widgets/k_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.currentUser,
    required this.activeRole,
  });

  final UserProfile currentUser;
  final UserRole activeRole;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class QuickMatchVisibilitySwitch extends StatelessWidget {
  const QuickMatchVisibilitySwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Visibilidad en Quick Match',
      child: Switch(
        value: value,
        activeThumbColor: KairosPalette.primary,
        onChanged: onChanged,
      ),
    );
  }
}

class _ProfilePageState extends State<ProfilePage> {
  final _api = ApiClient();
  final _picker = ImagePicker();

  bool _isUploadingAvatar = false;
  bool _isDownloadingReport = false;
  bool _isDownloadingCv = false;
  String? _uploadedAvatarUrl;

  late bool _quickMatchVisible;
  bool _togglingQuickMatch = false;

  List<Map<String, dynamic>> _skillCatalog = [];
  final Set<int> _mySkillIds = {};
  final Set<int> _togglingSkillIds = {};
  bool _loadingSkills = true;

  /// Perfil y métricas reales traídos de `/users/me`. Antes la pantalla solo
  /// conocía lo que vino en la respuesta del login, así que las conexiones
  /// salían siempre en cero y las visitas y publicaciones eran literales.
  Map<String, dynamic>? _profile;

  /// Preferencias de privacidad. Arrancan abiertas, que es como funcionaba la
  /// plataforma antes de existir esta opción.
  String _messagePrivacy = 'everyone';
  String _postVisibility = 'everyone';
  bool _savingPrivacy = false;

  @override
  void initState() {
    super.initState();
    _quickMatchVisible = widget.currentUser.quickMatchVisible;
    _loadProfile();
    if (widget.activeRole == UserRole.student) _loadSkills();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.getMyProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Sin métricas la pantalla sigue mostrando los datos de la sesión.
    }

    try {
      final privacy = await _api.getMyPrivacy();
      if (mounted) {
        setState(() {
          _messagePrivacy = privacy['messagePrivacy'] as String? ?? 'everyone';
          _postVisibility = privacy['postVisibility'] as String? ?? 'everyone';
        });
      }
    } catch (_) {
      // Se mantienen los valores abiertos, que son los de por defecto.
    }
  }

  /// Guarda ambas preferencias juntas: el endpoint las trata como un par y
  /// enviar solo una borraría la otra.
  Future<void> _savePrivacy({String? messages, String? posts}) async {
    final previousMessages = _messagePrivacy;
    final previousPosts = _postVisibility;

    setState(() {
      _messagePrivacy = messages ?? _messagePrivacy;
      _postVisibility = posts ?? _postVisibility;
      _savingPrivacy = true;
    });

    try {
      await _api.updateMyPrivacy(
        messagePrivacy: _messagePrivacy,
        postVisibility: _postVisibility,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messagePrivacy = previousMessages;
        _postVisibility = previousPosts;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la preferencia.'),
          backgroundColor: KairosPalette.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingPrivacy = false);
    }
  }

  int _metric(String key) => _profile?[key] as int? ?? 0;

  Future<void> _loadSkills() async {
    try {
      final results = await Future.wait([_api.getSkills(), _api.getMySkills()]);
      if (mounted) {
        setState(() {
          _skillCatalog = results[0] as List<Map<String, dynamic>>;
          _mySkillIds
            ..clear()
            ..addAll((results[1] as List<int>));
        });
      }
    } catch (_) {
      // Si falla, el picker simplemente queda vacío; el usuario puede reintentar más tarde.
    } finally {
      if (mounted) setState(() => _loadingSkills = false);
    }
  }

  Future<void> _toggleSkill(int skillId) async {
    final wasSelected = _mySkillIds.contains(skillId);
    setState(() {
      _togglingSkillIds.add(skillId);
      if (wasSelected) {
        _mySkillIds.remove(skillId);
      } else {
        _mySkillIds.add(skillId);
      }
    });
    try {
      if (wasSelected) {
        await _api.removeMySkill(skillId);
      } else {
        await _api.addMySkill(skillId);
      }
      final skill = _skillCatalog.firstWhere(
        (s) => s['id'] == skillId,
        orElse: () => const {'name': 'desconocida'},
      );
      Analytics.skillToggle(skill['name'] as String, !wasSelected);
    } catch (_) {
      if (mounted) {
        setState(() {
          if (wasSelected) {
            _mySkillIds.add(skillId);
          } else {
            _mySkillIds.remove(skillId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo actualizar tu competencia. Intenta de nuevo.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingSkillIds.remove(skillId));
    }
  }

  Future<void> _toggleQuickMatchVisibility(bool value) async {
    setState(() {
      _togglingQuickMatch = true;
      _quickMatchVisible = value;
    });
    try {
      final confirmed = await _api.setQuickMatchVisibility(value);
      Analytics.quickMatchVisibility(confirmed);
      if (mounted) setState(() => _quickMatchVisible = confirmed);
    } catch (_) {
      if (mounted) {
        setState(() => _quickMatchVisible = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo actualizar tu visibilidad en Quick Match.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingQuickMatch = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final result = await _api.uploadImage(image);
      setState(() => _uploadedAvatarUrl = result['cdnUrl'] as String?);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir la imagen.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _downloadReport() async {
    setState(() => _isDownloadingReport = true);
    try {
      final now = DateTime.now();
      final bytes = await _api.downloadReport(month: now.month, year: now.year);
      Analytics.downloadReport();
      downloadFile(
        bytes,
        'kairos-reporte-${now.year}-${now.month.toString().padLeft(2, '0')}.pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reporte descargado.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al descargar el reporte.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingReport = false);
    }
  }

  Future<void> _downloadCv() async {
    setState(() => _isDownloadingCv = true);
    try {
      final bytes = await _api.downloadCurriculum();
      Analytics.downloadCv();
      final now = DateTime.now();
      downloadFile(
        bytes,
        'kairos-cv-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CV descargado exitosamente.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al generar el CV. Intenta de nuevo.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingCv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(user),
              const SizedBox(height: 12),
              if (user.socioemotionalTest != null) ...[
                _buildSocioemotional(user.socioemotionalTest!),
                const SizedBox(height: 12),
              ],
              _buildAbout(user),
              const SizedBox(height: 12),
              _buildSkills(user),
              if (widget.activeRole == UserRole.student) ...[
                const SizedBox(height: 12),
                _buildQuickMatchVisibility(),
              ],
              const SizedBox(height: 12),
              _buildPrivacy(),
              if (widget.activeRole == UserRole.student ||
                  widget.activeRole == UserRole.alumni) ...[
                const SizedBox(height: 12),
                _buildExperience(),
                const SizedBox(height: 12),
                _buildCertifications(),
                const SizedBox(height: 12),
                _buildProjects(),
              ],
              const SizedBox(height: 12),
              _buildReportCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(UserProfile user) {
    final avatarUrl = (_uploadedAvatarUrl ?? user.avatarUrl).trim();
    final availableWidth = MediaQuery.sizeOf(context).width;
    final compactActions = availableWidth < 760;
    return KCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 130,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x260F766E), Color(0x1000B5AD)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(0, -52),
                  child: Stack(
                    children: [
                      Semantics(
                        image: true,
                        label: avatarUrl.isEmpty
                            ? 'Sin foto de perfil'
                            : 'Foto de perfil de ${user.name}',
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 47,
                            backgroundImage: avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl.isEmpty
                                ? const ExcludeSemantics(
                                    child: Icon(Icons.person_rounded),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: IconButton(
                          onPressed: _isUploadingAvatar
                              ? null
                              : _pickAndUploadAvatar,
                          tooltip: _isUploadingAvatar
                              ? 'Subiendo foto de perfil'
                              : 'Cambiar foto de perfil',
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: KairosPalette.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _isUploadingAvatar
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    compactActions
                        ? IconButton.filled(
                            onPressed: _showEditProfileDialog,
                            tooltip: 'Editar perfil',
                            icon: const Icon(Icons.edit_rounded, size: 18),
                          )
                        : ElevatedButton.icon(
                            onPressed: _showEditProfileDialog,
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('Editar perfil'),
                          ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _titleForRole(widget.activeRole),
                  style: const TextStyle(
                    color: KairosPalette.secondary,
                    fontSize: 16,
                  ),
                ),
                if (user.specialization != null) ...[
                  const SizedBox(height: 8),
                  Chip(
                    label: Text('Especializacion: ${user.specialization}'),
                    side: BorderSide.none,
                    backgroundColor: KairosPalette.muted,
                  ),
                ],
                const SizedBox(height: 8),
                if (user.institution != null && user.institution!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_rounded,
                          size: 16,
                          color: KairosPalette.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            user.institution!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: KairosPalette.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    if (user.location.isNotEmpty)
                      _meta(Icons.pin_drop_rounded, user.location),
                    _meta(
                      Icons.group_rounded,
                      '${user.connections} conexiones',
                    ),
                    if (user.graduationYear != null)
                      _meta(
                        Icons.school_rounded,
                        'Egreso ${user.graduationYear}',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // "Visitas perfil" mostraba un 23 fijo y "Publicaciones" un
                    // 8: ninguno de los dos consultaba nada. Las visitas no se
                    // registran en ninguna parte, así que esa tarjeta se
                    // reemplaza por un dato que sí existe.
                    _counter('${_metric('connectionCount')}', 'Conexiones'),
                    _counter('${_metric('skillCount')}', 'Competencias'),
                    _counter('${_metric('postCount')}', 'Publicaciones'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Socioemotional ──────────────────────────────────────────────────────────

  Widget _buildSocioemotional(SocioemotionalTest test) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_rounded, color: KairosPalette.primary),
              SizedBox(width: 8),
              Text(
                'Evaluacion socioemocional',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (test.completed) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KairosPalette.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Test completado: ${test.completedDate ?? '-'}'),
            ),
            const SizedBox(height: 12),
            ...test.skills.map(
              (skill) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            skill.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (skill.badge)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: KairosPalette.accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: LinearProgressIndicator(
                        value: skill.level / 5,
                        minHeight: 9,
                        borderRadius: BorderRadius.circular(20),
                        backgroundColor: KairosPalette.border,
                        color: KairosPalette.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${skill.level}/5'),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Text(
              'Test pendiente. Realizar el test puede mejorar la visibilidad de tu perfil.',
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: KairosPalette.accent,
              ),
              onPressed: () {},
              child: const Text('Realizar test ahora'),
            ),
          ],
        ],
      ),
    );
  }

  // ── About ────────────────────────────────────────────────────────────────────

  Widget _buildAbout(UserProfile user) {
    // La descripción guardada manda sobre la de la sesión, que puede estar
    // desactualizada si el usuario acaba de editar su perfil.
    final bio = (_profile?['bio'] as String?)?.trim() ?? user.bio.trim();
    final isCompany = widget.activeRole == UserRole.company;

    return SizedBox(
      width: double.infinity,
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCompany ? 'Sobre la empresa' : 'Acerca de mí',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (bio.isEmpty)
              // Una tarjeta vacía no dice si falta contenido o si algo falló.
              _emptySection(
                message: isCompany
                    ? 'Todavía no has descrito a qué se dedica tu empresa.'
                    : 'Todavía no has escrito nada sobre ti.',
                actionLabel: 'Agregar descripción',
                onPressed: _showEditProfileDialog,
              )
            else
              Text(bio, style: const TextStyle(height: 1.45)),
          ],
        ),
      ),
    );
  }

  /// Preferencias de privacidad.
  ///
  /// Existen porque en una plataforma con menores de edad "todo el mundo puede
  /// escribirte" no debería ser la única opción posible.
  Widget _buildPrivacy() {
    return SizedBox(
      width: double.infinity,
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: KairosPalette.primary),
                SizedBox(width: 8),
                Text(
                  'Privacidad',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _messagePrivacy,
              decoration: const InputDecoration(
                labelText: 'Quién puede enviarme mensajes',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'everyone',
                  child: Text('Cualquier persona'),
                ),
                DropdownMenuItem(
                  value: 'connections',
                  child: Text('Solo mis contactos'),
                ),
                DropdownMenuItem(
                  value: 'staff',
                  child: Text('Solo el personal del liceo'),
                ),
              ],
              onChanged: _savingPrivacy
                  ? null
                  : (value) {
                      if (value != null) _savePrivacy(messages: value);
                    },
            ),
            const SizedBox(height: 6),
            const Text(
              'El personal del liceo siempre puede escribirte. Si te ofreces en '
              'Quick Match, las empresas también.',
              style: TextStyle(
                fontSize: 12,
                color: KairosPalette.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _postVisibility,
              decoration: const InputDecoration(
                labelText: 'Quién ve mis publicaciones',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'everyone',
                  child: Text('Toda la plataforma'),
                ),
                DropdownMenuItem(
                  value: 'connections',
                  child: Text('Solo mis contactos'),
                ),
              ],
              onChanged: _savingPrivacy
                  ? null
                  : (value) {
                      if (value != null) _savePrivacy(posts: value);
                    },
            ),
            const SizedBox(height: 6),
            const Text(
              'Se aplica a las publicaciones que ya hiciste, no solo a las nuevas.',
              style: TextStyle(
                fontSize: 12,
                color: KairosPalette.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Estado vacío de una sección del perfil: explica que falta contenido y
  /// ofrece el camino para agregarlo, en vez de dejar la tarjeta en blanco.
  Widget _emptySection({
    required String message,
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(color: KairosPalette.mutedForeground),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(actionLabel),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
      ],
    );
  }

  // ── Skills ───────────────────────────────────────────────────────────────────

  static const _categoryLabels = {
    'Technical': 'Habilidades técnicas',
    'Language': 'Idiomas',
    'Experience': 'Experiencia previa',
  };

  Widget _buildSkills(UserProfile user) {
    if (widget.activeRole != UserRole.student) {
      return SizedBox(
        width: double.infinity,
        child: KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Habilidades tecnicas',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.skills
                    .map(
                      (skill) =>
                          Chip(label: Text(skill), side: BorderSide.none),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Competencias',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Toca una competencia para agregarla o quitarla de tu perfil.',
              style: TextStyle(color: KairosPalette.secondary),
            ),
            const SizedBox(height: 12),
            if (_loadingSkills)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              ..._categoryLabels.entries.map((entry) {
                final items = _skillCatalog
                    .where((s) => s['category'] == entry.key)
                    .toList(growable: false);
                if (items.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: KairosPalette.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: items
                            .map((skill) {
                              final id = skill['id'] as int;
                              final selected = _mySkillIds.contains(id);
                              final toggling = _togglingSkillIds.contains(id);
                              return FilterChip(
                                label: Text(skill['name'] as String),
                                selected: selected,
                                showCheckmark: false,
                                avatar: toggling
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : null,
                                selectedColor: KairosPalette.primary.withValues(
                                  alpha: 0.15,
                                ),
                                labelStyle: TextStyle(
                                  color: selected
                                      ? KairosPalette.primary
                                      : null,
                                  fontWeight: selected ? FontWeight.w700 : null,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? KairosPalette.primary
                                      : KairosPalette.border,
                                ),
                                onSelected: toggling
                                    ? null
                                    : (_) => _toggleSkill(id),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ── Quick Match visibility ────────────────────────────────────────────────────

  Widget _buildQuickMatchVisibility() {
    return SizedBox(
      width: double.infinity,
      child: KCard(
        borderColor: _quickMatchVisible
            ? KairosPalette.primary.withValues(alpha: 0.4)
            : KairosPalette.border,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: KairosPalette.muted,
              child: Icon(Icons.bolt_rounded, color: KairosPalette.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Visible en Quick Match',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _quickMatchVisible
                        ? 'Las empresas pueden encontrarte al buscar por competencias y contactarte directamente.'
                        : 'Actívalo para que las empresas puedan encontrarte al buscar candidatos por competencias.',
                    style: const TextStyle(color: KairosPalette.secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _togglingQuickMatch
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : QuickMatchVisibilitySwitch(
                    value: _quickMatchVisible,
                    onChanged: _toggleQuickMatchVisibility,
                  ),
          ],
        ),
      ),
    );
  }

  // ── Experience ───────────────────────────────────────────────────────────────

  Widget _buildExperience() {
    const exp = [
      (
        'Proyecto de Robotica - Competencia Regional',
        'Liceo Tecnico Cardenal Jose Maria Caro',
        'La Florida, Santiago  2025-2026',
        'Diseno y programacion de robot autonomo de clasificacion. Primer lugar regional.',
      ),
      (
        'Ayudante de Laboratorio',
        'Liceo Tecnico Cardenal Jose Maria Caro',
        'La Florida, Santiago  2025',
        'Apoyo en mantencion y preparacion de equipos de laboratorio de mecatronica.',
      ),
    ];

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Experiencia',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...exp.map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              minLeadingWidth: 52,
              leading: _sectionBubble(Icons.work_rounded),
              title: Text(
                e.$1,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${e.$2}\n${e.$3}\n${e.$4}'),
              isThreeLine: true,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar experiencia'),
          ),
        ],
      ),
    );
  }

  // ── Certifications ───────────────────────────────────────────────────────────

  Widget _buildCertifications() {
    const certs = [
      ('Curso de Arduino Avanzado', 'INACAP  2025'),
      ('Certificacion en Impresion 3D', 'FabLab Santiago  2025'),
      ('Programacion en C++', 'Coursera  2024'),
    ];

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Certificaciones y formacion',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...certs.map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              minLeadingWidth: 52,
              leading: _sectionBubble(Icons.school_rounded),
              title: Text(
                c.$1,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(c.$2),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar certificacion'),
          ),
        ],
      ),
    );
  }

  // ── Projects ─────────────────────────────────────────────────────────────────

  Widget _buildProjects() {
    const projects = [
      (
        'Robot Clasificador Autonomo',
        'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=900',
        'Robot que clasifica objetos por color y tamano usando sensores y Arduino.',
      ),
      (
        'Sistema de Riego Automatizado',
        'https://images.unsplash.com/photo-1530836369250-ef72a3f5cda8?w=900',
        'Control de riego por humedad del suelo y temperatura para invernadero.',
      ),
    ];

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proyectos destacados',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cross = constraints.maxWidth > 800 ? 2 : 1;
              return GridView.builder(
                itemCount: projects.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, index) {
                  final p = projects[index];
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: KairosPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(15),
                              topRight: Radius.circular(15),
                            ),
                            child: Image.network(
                              p.$2,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              semanticLabel: 'Proyecto ${p.$1}: ${p.$3}',
                              errorBuilder: (context, error, stackTrace) =>
                                  Semantics(
                                    image: true,
                                    label:
                                        'Proyecto ${p.$1}: ${p.$3}. Imagen no disponible.',
                                    child: const ColoredBox(
                                      color: KairosPalette.muted,
                                      child: Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          color: KairosPalette.secondary,
                                        ),
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.$3,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Report ───────────────────────────────────────────────────────────────────

  Widget _buildReportCard() {
    return KCard(
      borderColor: KairosPalette.primary.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: KairosPalette.primary),
              SizedBox(width: 8),
              Text(
                'Documentos PDF',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Genera y descarga tu CV o el reporte mensual de actividad.',
            style: TextStyle(color: KairosPalette.secondary),
          ),
          const SizedBox(height: 14),
          // ── CV ──────────────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isDownloadingCv ? null : _downloadCv,
              style: ElevatedButton.styleFrom(
                backgroundColor: KairosPalette.accent,
              ),
              icon: _isDownloadingCv
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.badge_rounded, size: 18),
              label: Text(
                _isDownloadingCv ? 'Generando CV...' : 'Generar y descargar CV',
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ── Reporte mensual ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isDownloadingReport ? null : _downloadReport,
              style: OutlinedButton.styleFrom(
                foregroundColor: KairosPalette.primary,
                side: const BorderSide(color: KairosPalette.primary),
              ),
              icon: _isDownloadingReport
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: const Text('Descargar reporte mensual'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _meta(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: KairosPalette.secondary),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: KairosPalette.secondary)),
      ],
    );
  }

  /// Formulario de edición del perfil propio.
  ///
  /// Solo expone lo que el usuario puede cambiar de sí mismo. El correo, el
  /// nombre de usuario y el rol quedan fuera a propósito: son la identidad de
  /// la cuenta y su cambio corresponde al liceo.
  void _showEditProfileDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(
      text: _profile?['fullName'] as String? ?? widget.currentUser.name,
    );
    final bioCtrl = TextEditingController(
      text: _profile?['bio'] as String? ?? '',
    );
    final institutionCtrl = TextEditingController(
      text: _profile?['institution'] as String? ?? '',
    );
    var saving = false;

    final isCompany = widget.activeRole == UserRole.company;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text(
            'Editar perfil',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: isCompany
                            ? 'Nombre de la empresa *'
                            : 'Nombre completo *',
                        counterText: '',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'El nombre no puede quedar vacío'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: institutionCtrl,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: isCompany ? 'Ubicación' : 'Curso o liceo',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bioCtrl,
                      maxLength: 500,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: isCompany ? 'Sobre la empresa' : 'Sobre mí',
                        hintText: isCompany
                            ? 'A qué se dedica, qué perfiles busca...'
                            : 'Qué estudias, qué te interesa, en qué has trabajado...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setInner(() => saving = true);
                      try {
                        final updated = await _api.updateMyProfile(
                          fullName: nameCtrl.text.trim(),
                          bio: bioCtrl.text.trim(),
                          institution: institutionCtrl.text.trim(),
                          profilePictureUrl:
                              _uploadedAvatarUrl ??
                              _profile?['profilePictureUrl'] as String?,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() {
                          _profile = {...?_profile, ...updated};
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Perfil actualizado.'),
                            backgroundColor: KairosPalette.success,
                          ),
                        );
                      } catch (_) {
                        setInner(() => saving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo guardar el perfil.'),
                            backgroundColor: KairosPalette.danger,
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _counter(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: KairosPalette.primary,
            ),
          ),
          Text(label, style: const TextStyle(color: KairosPalette.secondary)),
        ],
      ),
    );
  }

  Widget _sectionBubble(IconData icon) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: KairosPalette.muted,
      child: Icon(icon, size: 20, color: KairosPalette.primary),
    );
  }

  String _titleForRole(UserRole role) => switch (role) {
    UserRole.student => 'Estudiante',
    UserRole.alumni => 'Egresado / Alumni',
    UserRole.staff => 'Staff del Liceo',
    UserRole.company => 'Empresa / Reclutador',
  };
}
