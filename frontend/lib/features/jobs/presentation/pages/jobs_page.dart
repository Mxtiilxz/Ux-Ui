import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/analytics/analytics.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/kairos_palette.dart';
import '../../../../core/utils/file_downloader.dart';
import '../../../../core/widgets/k_card.dart';
import '../../data/models/job_model.dart';
import 'company_jobs_page.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({
    super.key,
    required this.role,
    required this.currentUser,
    this.onOpenChat,
  });

  final UserRole role;
  final UserProfile currentUser;

  /// Called with the target user's id after successfully contacting a Quick
  /// Match candidate, so the host app can switch to the Chats tab.
  final void Function(String userId)? onOpenChat;

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _savedJobs = <String>{};

  /// Cuando está activo, la lista muestra solo las ofertas guardadas. Sin esto,
  /// guardar una oferta no servía para nada: no había forma de volver a ellas.
  bool _onlySaved = false;
  OpportunityType? _selectedType;
  String? _selectedSpecialization;

  final _api = ApiClient();
  final _picker = ImagePicker();
  List<JobModel> _apiJobs = [];
  bool _jobsLoading = true;
  bool _generatingCv = false;
  final Set<String> _appliedJobs = <String>{};

  // ── Quick Match (empresa) ────────────────────────────────────────────────────
  List<Map<String, dynamic>> _skillCatalog = [];
  bool _loadingSkillCatalog = true;
  final Set<int> _selectedSkillIds = {};
  List<Map<String, dynamic>> _candidates = [];
  bool _searchingCandidates = false;
  bool _hasSearchedCandidates = false;
  final Set<int> _contactingIds = {};
  final Set<int> _contactedIds = {};

  // ── Mensaje de contacto editable por la empresa ──────────────────────────────
  // Placeholders soportados: {nombre} (candidato), {empresa} (esta empresa),
  // {competencias} (competencias coincidentes). Debe reflejar el default del
  // backend (QuickMatchDefaults.MessageTemplate).
  static const String _defaultMessageTemplate =
      'Hola {nombre}, te contactamos desde {empresa}. Vimos que dominas {competencias} '
      'y nos encantaría conversar contigo sobre una oportunidad de práctica. ¿Te interesaría?';
  String _messageTemplate = _defaultMessageTemplate;
  bool _messageIsDefault = true;
  bool _loadingMessageTemplate = true;

  static const List<String> _specializations = [
    'Mecatronica',
    'Automatizacion',
    'Recursos Humanos',
    'Mecanica',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.role == UserRole.company) {
      _loadSkillCatalog();
      _loadMessageTemplate();
    } else {
      _loadJobs();
      _loadSavedJobs();
    }
  }

  Future<void> _loadJobs() async {
    try {
      final data = await _api.getJobs();
      final items = (data['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(JobModel.fromJson)
          .toList();
      if (mounted) setState(() => _apiJobs = items);
    } catch (_) {
      if (mounted) setState(() => _apiJobs = []);
    } finally {
      if (mounted) setState(() => _jobsLoading = false);
    }
  }

  Future<void> _generateCv() async {
    setState(() => _generatingCv = true);
    try {
      final bytes = await _api.downloadCurriculum();
      Analytics.downloadCv();
      downloadFile(bytes, 'kairos-cv.pdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CV generado y descargado.'),
            backgroundColor: KairosPalette.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo generar el CV. Intenta de nuevo.'),
            backgroundColor: KairosPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingCv = false);
    }
  }

  Future<void> _loadSavedJobs() async {
    try {
      final ids = await _api.getSavedJobs();
      if (!mounted) return;
      setState(() {
        _savedJobs
          ..clear()
          ..addAll(ids.map((id) => id.toString()));
      });
    } catch (_) {
      // Sin guardadas la pestaña sigue siendo usable; no vale interrumpir.
    }
  }

  /// Guarda o quita la oferta en el servidor. Se actualiza la interfaz primero
  /// para que el marcador responda al instante, y se revierte si falla.
  Future<void> _toggleSaved(JobModel job) async {
    final jobId = int.tryParse(job.id);
    if (jobId == null) return;

    final wasSaved = _savedJobs.contains(job.id);
    setState(() {
      if (wasSaved) {
        _savedJobs.remove(job.id);
      } else {
        _savedJobs.add(job.id);
      }
    });

    try {
      final nowSaved = await _api.toggleSavedJob(jobId);
      if (!mounted) return;
      setState(() {
        if (nowSaved) {
          _savedJobs.add(job.id);
        } else {
          _savedJobs.remove(job.id);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _savedJobs.add(job.id);
        } else {
          _savedJobs.remove(job.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la oferta.'),
          backgroundColor: KairosPalette.danger,
        ),
      );
    }
  }

  Future<void> _applyToJob(JobModel job) async {
    final jobId = int.tryParse(job.id);
    if (jobId == null) return;
    try {
      await _api.applyToJob(jobId);
      Analytics.jobApply(job.title);
      if (mounted) {
        setState(() => _appliedJobs.add(job.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Postulación enviada a ${job.company}!'),
            backgroundColor: KairosPalette.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar la postulación.'),
            backgroundColor: KairosPalette.danger,
          ),
        );
      }
    }
  }

  // ── Quick Match (empresa) ────────────────────────────────────────────────────

  Future<void> _loadSkillCatalog() async {
    setState(() => _loadingSkillCatalog = true);
    try {
      final catalog = await _api.getSkills();
      if (mounted) setState(() => _skillCatalog = catalog);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cargar el catálogo de competencias.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSkillCatalog = false);
    }
  }

  Future<void> _loadMessageTemplate() async {
    try {
      final data = await _api.getCompanyMessageTemplate();
      final template = (data['template'] as String?)?.trim();
      if (mounted) {
        setState(() {
          _messageTemplate = (template != null && template.isNotEmpty)
              ? template
              : _defaultMessageTemplate;
          _messageIsDefault = data['isDefault'] as bool? ?? true;
        });
      }
    } catch (_) {
      // Si falla, se mantiene la plantilla por defecto local.
    } finally {
      if (mounted) setState(() => _loadingMessageTemplate = false);
    }
  }

  /// Rellena la plantilla con los datos del candidato y la empresa.
  String _buildContactMessage({
    required String candidateName,
    required String skills,
  }) {
    final competencias = skills.trim().isEmpty ? 'tu perfil' : skills.trim();
    final template = _messageTemplate.trim().isEmpty
        ? _defaultMessageTemplate
        : _messageTemplate;
    return template
        .replaceAll('{nombre}', candidateName)
        .replaceAll('{empresa}', widget.currentUser.name)
        .replaceAll('{competencias}', competencias)
        .trim();
  }

  void _toggleSearchSkill(int skillId) {
    final willSelect = !_selectedSkillIds.contains(skillId);
    final skill = _skillCatalog.firstWhere(
      (s) => s['id'] == skillId,
      orElse: () => const {'name': 'desconocida'},
    );
    Analytics.quickMatchSkillToggle(skill['name'] as String, willSelect);
    setState(() {
      if (willSelect) {
        _selectedSkillIds.add(skillId);
      } else {
        _selectedSkillIds.remove(skillId);
      }
    });
  }

  Future<void> _searchCandidates() async {
    if (_selectedSkillIds.isEmpty) return;
    setState(() {
      _searchingCandidates = true;
      _hasSearchedCandidates = true;
    });
    try {
      final results = await _api.searchCandidates(_selectedSkillIds.toList());
      Analytics.quickMatchSearch(_selectedSkillIds.length, results.length);
      if (mounted) setState(() => _candidates = results);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo buscar candidatos. Intenta de nuevo.'),
            backgroundColor: KairosPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _searchingCandidates = false);
    }
  }

  Future<void> _contactCandidate(Map<String, dynamic> candidate) async {
    final id = candidate['id'] as int;
    final candidateName = candidate['fullName'] as String? ?? 'Estudiante';
    final matched = (candidate['matchedSkills'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final skillNames = matched.map((s) => s['name'] as String).join(', ');
    final message = _buildContactMessage(
      candidateName: candidateName,
      skills: skillNames,
    );

    setState(() => _contactingIds.add(id));
    try {
      await _api.sendMessage(id, message);
      Analytics.quickMatchContact(candidate['matchPercentage'] as int? ?? 0);
      if (mounted) {
        setState(() {
          _contactedIds.add(id);
          _contactingIds.remove(id);
        });
        widget.onOpenChat?.call(id.toString());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _contactingIds.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo contactar. Intenta de nuevo.'),
            backgroundColor: KairosPalette.danger,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == UserRole.company) {
      return _buildCompanyView(context);
    }

    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 760;
    final pagePadding = mobile
        ? const EdgeInsets.fromLTRB(14, 14, 14, 16)
        : const EdgeInsets.all(20);
    // Solo ofertas reales. Antes, una lista vacía legítima —una empresa que aún
    // no publica nada— se sustituía por ofertas de ejemplo.
    final filteredJobs = _apiJobs.where(_matchesFilter).toList(growable: false);

    return SingleChildScrollView(
      padding: pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oportunidades Laborales',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Practicas y trabajos del Liceo Tecnico Cardenal Jose Maria Caro',
                ),
              ],
            )
          else
            const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Oportunidades Laborales',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Practicas y trabajos del Liceo Tecnico Cardenal Jose Maria Caro',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          KCard(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x1A0F766E), Color(0xFFE8F3EF)],
            ),
            borderColor: KairosPalette.primary,
            child: mobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: KairosPalette.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Automatiza tu CV',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Genera CVs personalizados para cada oferta en segundos.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _generatingCv ? null : _generateCv,
                          icon: _generatingCv
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.bolt_rounded),
                          label: Text(
                            _generatingCv ? 'Generando...' : 'Generar CV',
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: KairosPalette.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Automatiza tu CV',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Genera CVs personalizados para cada oferta en segundos.',
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _generatingCv ? null : _generateCv,
                        icon: _generatingCv
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.bolt_rounded),
                        label: Text(
                          _generatingCv ? 'Generando...' : 'Generar CV',
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar ofertas',
                    hintText: 'Buscar por habilidad, empresa o cargo...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () =>
                                setState(() => _searchController.clear()),
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tipo de oportunidad',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _typeChip('Todas', null),
                    _typeChip('Practicas', OpportunityType.practice),
                    _typeChip('Trabajos', OpportunityType.job),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Especializacion',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _specializationChip('Todas', null),
                    ..._specializations.map((s) => _specializationChip(s, s)),
                    // Sin este filtro, guardar una oferta no servía de nada:
                    // no había forma de volver a las guardadas.
                    FilterChip(
                      avatar: Icon(
                        _onlySaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 18,
                      ),
                      label: Text('Guardadas (${_savedJobs.length})'),
                      selected: _onlySaved,
                      onSelected: (value) => setState(() => _onlySaved = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (mobile)
            Column(
              children: [
                _statCard(
                  Icons.work_rounded,
                  '${filteredJobs.length}',
                  'Ofertas activas',
                ),
                const SizedBox(height: 10),
                _statCard(
                  Icons.bookmark_rounded,
                  '${_savedJobs.length}',
                  'Guardadas',
                ),
                const SizedBox(height: 10),
                _statCard(
                  Icons.schedule_rounded,
                  '${_appliedJobs.length}',
                  'Postuladas',
                ),
              ],
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 900;
                return GridView.count(
                  crossAxisCount: wide ? 3 : 1,
                  childAspectRatio: wide ? 3 : 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _statCard(
                      Icons.work_rounded,
                      '${filteredJobs.length}',
                      'Ofertas activas',
                    ),
                    _statCard(
                      Icons.bookmark_rounded,
                      '${_savedJobs.length}',
                      'Guardadas',
                    ),
                    _statCard(
                      Icons.schedule_rounded,
                      '${_appliedJobs.length}',
                      'Postuladas',
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 12),
          if (_jobsLoading)
            Semantics(
              liveRegion: true,
              container: true,
              label: 'Cargando ofertas laborales',
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (filteredJobs.isEmpty)
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  // "Sin ofertas" y "sin coincidencias" son situaciones distintas:
                  // en la primera no hay filtro que aflojar.
                  child: Text(
                    _apiJobs.isEmpty
                        ? 'Todavía no hay ofertas publicadas.'
                        : _onlySaved && _savedJobs.isEmpty
                        ? 'No has guardado ninguna oferta todavía.'
                        : 'No hay resultados con esos filtros.',
                  ),
                ),
              ),
            )
          else
            ...filteredJobs.map(
              (job) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _jobTile(job, mobile: mobile),
              ),
            ),
        ],
      ),
    );
  }

  bool _matchesFilter(JobModel job) {
    final query = _searchController.text.trim().toLowerCase();
    final matchesSearch =
        query.isEmpty ||
        job.title.toLowerCase().contains(query) ||
        job.company.toLowerCase().contains(query) ||
        job.skills.any((skill) => skill.toLowerCase().contains(query));
    final matchesType = _selectedType == null || job.type == _selectedType;
    final matchesSpecialization =
        _selectedSpecialization == null ||
        job.specializations.contains(_selectedSpecialization);
    final matchesSaved = !_onlySaved || _savedJobs.contains(job.id);
    return matchesSearch &&
        matchesType &&
        matchesSpecialization &&
        matchesSaved;
  }

  Widget _jobTile(JobModel job, {required bool mobile}) {
    final saved = _savedJobs.contains(job.id);
    final applied = _appliedJobs.contains(job.id);
    final applyButtonStyle = ElevatedButton.styleFrom(
      minimumSize: Size(mobile ? 0 : 136, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: applied ? KairosPalette.muted : KairosPalette.primary,
      foregroundColor: applied ? KairosPalette.foreground : Colors.white,
      elevation: 0,
    );
    final actionButtonStyle = OutlinedButton.styleFrom(
      minimumSize: Size(mobile ? 0 : 136, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: KairosPalette.primary),
      foregroundColor: KairosPalette.primary,
    );

    if (mobile) {
      return KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (job.imageUrl != null && job.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  job.imageUrl!,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                  semanticLabel: 'Imagen de la oferta ${job.title}',
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CompanyLogo(
                  logoUrl: job.logoUrl,
                  company: job.company,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 21,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.company,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: KairosPalette.secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _metaChip(Icons.pin_drop_rounded, job.location),
                _metaChip(Icons.work_rounded, job.type.label),
                if (job.salary != null)
                  _metaChip(Icons.attach_money_rounded, job.salary!),
                _metaChip(Icons.schedule_rounded, job.postedDate),
              ],
            ),
            const SizedBox(height: 8),
            Text(job.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: job.skills
                  .map(
                    (skill) => Chip(
                      label: Text(skill),
                      side: BorderSide.none,
                      backgroundColor: KairosPalette.muted,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: applied ? null : () => _applyToJob(job),
                    style: applyButtonStyle,
                    child: Text(applied ? 'Postulado' : 'Aplicar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showJobDetails(job),
                    style: actionButtonStyle,
                    child: const Text('Ver detalles'),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    tooltip: saved ? 'Quitar de guardadas' : 'Guardar',
                    onPressed: () => _toggleSaved(job),
                    icon: Icon(
                      saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return KCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (job.imageUrl != null && job.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                job.imageUrl!,
                width: double.infinity,
                height: 130,
                fit: BoxFit.cover,
                semanticLabel: 'Imagen de la oferta ${job.title}',
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CompanyLogo(
                  logoUrl: job.logoUrl,
                  company: job.company,
                  size: 58,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.company,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: KairosPalette.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _metaChip(Icons.pin_drop_rounded, job.location),
                          _metaChip(Icons.work_rounded, job.type.label),
                          if (job.salary != null)
                            _metaChip(Icons.attach_money_rounded, job.salary!),
                          _metaChip(Icons.schedule_rounded, job.postedDate),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(job.description),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: job.skills
                            .map(
                              (skill) => Chip(
                                label: Text(skill),
                                side: BorderSide.none,
                                backgroundColor: KairosPalette.muted,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: applied ? null : () => _applyToJob(job),
                          style: applyButtonStyle,
                          child: Text(applied ? 'Postulado' : 'Aplicar'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _showJobDetails(job),
                          style: actionButtonStyle,
                          child: const Text('Ver detalles'),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: saved ? 'Quitar de guardadas' : 'Guardar',
                      onPressed: () => _toggleSaved(job),
                      icon: Icon(
                        saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Detalle completo de una oferta. El botón "Ver detalles" existía desde el
  /// prototipo pero no hacía nada: la tarjeta recorta la descripción, así que
  /// no había forma de leer los requisitos completos antes de postular.
  void _showJobDetails(JobModel job) {
    final applied = _appliedJobs.contains(job.id);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          job.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.company,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: KairosPalette.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _metaChip(Icons.place_rounded, job.location),
                    if (job.postedDate.isNotEmpty)
                      _metaChip(Icons.schedule_rounded, job.postedDate),
                  ],
                ),
                if (job.imageUrl != null && job.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      job.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      semanticLabel: 'Imagen de la oferta ${job.title}',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Descripción',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(job.description),
                const SizedBox(height: 14),
                const Text(
                  'Competencias que se buscan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                if (job.skills.isEmpty)
                  const Text(
                    'La empresa no indicó competencias para esta oferta.',
                    style: TextStyle(color: KairosPalette.mutedForeground),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: job.skills
                        .map(
                          (skill) => Chip(
                            label: Text(skill),
                            side: BorderSide.none,
                            backgroundColor: KairosPalette.muted,
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          if (widget.role != UserRole.company)
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: applied
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _applyToJob(job);
                    },
              child: Text(applied ? 'Ya postulaste' : 'Postular'),
            ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: KairosPalette.secondary),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: KairosPalette.secondary)),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return KCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: KairosPalette.muted,
            ),
            child: Icon(icon, color: KairosPalette.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: KairosPalette.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String label, OpportunityType? type) {
    final selected = _selectedType == type;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedType = type),
      selectedColor: KairosPalette.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : KairosPalette.foreground,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _specializationChip(String label, String? value) {
    final selected = _selectedSpecialization == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedSpecialization = value),
      selectedColor: KairosPalette.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : KairosPalette.foreground,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _showCreateOfferDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;
    bool uploadingImg = false;
    String? uploadedImageUrl;
    // Competencias que pide la oferta. Es lo que la vuelve visible en Quick
    // Match y lo que alimenta el recuento de demanda del feed.
    final requestedSkillIds = <int>{};

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        hintText: 'Requisitos, beneficios, jornada...',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
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
                    const SizedBox(height: 16),
                    const Text(
                      'Competencias que buscas',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _skillCatalog.isEmpty
                          ? 'El liceo aún no ha publicado su catálogo de competencias.'
                          : 'Marcar competencias hace que la oferta aparezca en las '
                                'búsquedas de talento y le muestra al alumno si encaja.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: KairosPalette.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _skillCatalog
                          .map((skill) {
                            final id = skill['id'] as int;
                            final selected = requestedSkillIds.contains(id);
                            return FilterChip(
                              label: Text(skill['name'] as String? ?? ''),
                              selected: selected,
                              onSelected: (value) => setInner(() {
                                if (value) {
                                  requestedSkillIds.add(id);
                                } else {
                                  requestedSkillIds.remove(id);
                                }
                              }),
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 14),
                    // Image picker
                    if (uploadedImageUrl != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              uploadedImageUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              semanticLabel:
                                  'Imagen de la nueva oferta laboral',
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
                                tooltip: 'Quitar imagen de la oferta',
                                constraints: const BoxConstraints.tightFor(
                                  width: 48,
                                  height: 48,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => setInner(() {
                                  uploadedImageUrl = null;
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
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: uploadingImg
                            ? null
                            : () async {
                                final img = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );
                                if (img == null) return;
                                setInner(() {
                                  uploadingImg = true;
                                });
                                try {
                                  final result = await _api.uploadImage(img);
                                  setInner(
                                    () => uploadedImageUrl =
                                        result['cdnUrl'] as String?,
                                  );
                                } catch (_) {
                                  if (ctx.mounted)
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No se pudo subir la imagen.',
                                        ),
                                      ),
                                    );
                                } finally {
                                  setInner(() => uploadingImg = false);
                                }
                              },
                        icon: uploadingImg
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.add_photo_alternate_rounded,
                                size: 18,
                              ),
                        label: Text(
                          uploadingImg
                              ? 'Subiendo...'
                              : 'Agregar imagen (opcional)',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: KairosPalette.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setInner(() => submitting = true);
                      try {
                        await _api.createJobPosting(
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          location: locationCtrl.text.trim().isNotEmpty
                              ? locationCtrl.text.trim()
                              : null,
                          imageUrl: uploadedImageUrl,
                          skillIds: requestedSkillIds.toList(),
                        );
                        Analytics.jobCreate();
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        await _loadJobs();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Oferta publicada exitosamente.'),
                              backgroundColor: KairosPalette.success,
                            ),
                          );
                        }
                      } catch (_) {
                        setInner(() => submitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
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
                      width: 18,
                      height: 18,
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

  // ── Vista empresa: crear oferta + Quick Match ───────────────────────────────

  Widget _buildCompanyView(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pagePadding = width < 760
        ? const EdgeInsets.fromLTRB(14, 14, 14, 16)
        : const EdgeInsets.all(20);

    return SingleChildScrollView(
      padding: pagePadding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trabajos',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Publica ofertas y encuentra estudiantes destacados con Quick Match.',
              style: TextStyle(color: KairosPalette.secondary),
            ),
            const SizedBox(height: 16),
            KCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: KairosPalette.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_business_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crear oferta laboral',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Publica un cargo abierto en el feed de estudiantes.',
                          style: TextStyle(
                            color: KairosPalette.secondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateOfferDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KairosPalette.accent,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nueva oferta'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CompanyJobsPage()),
              ),
              icon: const Icon(Icons.manage_search_rounded, size: 18),
              label: const Text('Ver mis ofertas y postulantes'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Quick Match',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: KairosPalette.secondary,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            _buildContactMessageCard(),
            const SizedBox(height: 16),
            _buildQuickMatchSearchPanel(),
            const SizedBox(height: 16),
            _buildQuickMatchResults(),
          ],
        ),
      ),
    );
  }

  // ── Mensaje de contacto predeterminado (editable por la empresa) ─────────────

  Widget _buildContactMessageCard() {
    return KCard(
      borderColor: KairosPalette.primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KairosPalette.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.mark_chat_unread_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mensaje de contacto',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Se envía automáticamente al contactar a un candidato desde Quick Match.',
                      style: TextStyle(
                        color: KairosPalette.secondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loadingMessageTemplate
                    ? null
                    : _showEditMessageDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: KairosPalette.primary,
                  side: const BorderSide(color: KairosPalette.primary),
                ),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Editar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KairosPalette.muted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _loadingMessageTemplate
                ? Semantics(
                    liveRegion: true,
                    container: true,
                    label: 'Cargando mensaje de contacto',
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  )
                : Text(
                    _messageTemplate,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _messageIsDefault
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_rounded,
                size: 15,
                color: _messageIsDefault
                    ? KairosPalette.secondary
                    : KairosPalette.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _messageIsDefault
                      ? 'Estás usando el mensaje por defecto. Puedes personalizarlo.'
                      : 'Mensaje personalizado activo.',
                  style: const TextStyle(
                    color: KairosPalette.secondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditMessageDialog() {
    final controller = TextEditingController(text: _messageTemplate);
    bool saving = false;

    void insertToken(String token) {
      final text = controller.text;
      final sel = controller.selection;
      final start = sel.start < 0 ? text.length : sel.start;
      final end = sel.end < 0 ? text.length : sel.end;
      final newText = text.replaceRange(start, end, token);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + token.length),
      );
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text(
            'Editar mensaje de contacto',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Mensaje de contacto',
                      hintText:
                          'Escribe el mensaje que recibirán los candidatos...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toca para insertar:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final token in const [
                        '{nombre}',
                        '{empresa}',
                        '{competencias}',
                      ])
                        ActionChip(
                          label: Text(
                            token,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: KairosPalette.primary.withValues(
                            alpha: 0.12,
                          ),
                          side: BorderSide.none,
                          onPressed: () => insertToken(token),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '{nombre}: nombre del candidato\n'
                    '{empresa}: el nombre de tu empresa\n'
                    '{competencias}: competencias coincidentes',
                    style: TextStyle(
                      color: KairosPalette.secondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => controller.text = _defaultMessageTemplate,
              child: const Text('Restablecer'),
            ),
            TextButton(
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: KairosPalette.primary,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      setInner(() => saving = true);
                      try {
                        final data = await _api.setCompanyMessageTemplate(
                          controller.text.trim(),
                        );
                        Analytics.quickMatchTemplateEdit(
                          data['isDefault'] as bool? ?? false,
                        );
                        final template = (data['template'] as String?)?.trim();
                        if (mounted) {
                          setState(() {
                            _messageTemplate =
                                (template != null && template.isNotEmpty)
                                ? template
                                : _defaultMessageTemplate;
                            _messageIsDefault =
                                data['isDefault'] as bool? ?? true;
                          });
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mensaje de contacto actualizado.'),
                              backgroundColor: KairosPalette.success,
                            ),
                          );
                        }
                      } catch (_) {
                        setInner(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No se pudo guardar el mensaje. Intenta de nuevo.',
                              ),
                              backgroundColor: KairosPalette.danger,
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
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

  Widget _buildQuickMatchSearchPanel() {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buscando candidatos con estas competencias',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: KairosPalette.secondary,
            ),
          ),
          const SizedBox(height: 10),
          if (_loadingSkillCatalog)
            Semantics(
              liveRegion: true,
              container: true,
              label: 'Cargando competencias',
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skillCatalog
                  .map((skill) {
                    final id = skill['id'] as int;
                    final selected = _selectedSkillIds.contains(id);
                    return FilterChip(
                      label: Text(skill['name'] as String),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: KairosPalette.primary.withValues(
                        alpha: 0.15,
                      ),
                      labelStyle: TextStyle(
                        color: selected ? KairosPalette.primary : null,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                      side: BorderSide(
                        color: selected
                            ? KairosPalette.primary
                            : KairosPalette.border,
                      ),
                      onSelected: (_) => _toggleSearchSkill(id),
                    );
                  })
                  .toList(growable: false),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedSkillIds.isEmpty || _searchingCandidates
                  ? null
                  : _searchCandidates,
              style: ElevatedButton.styleFrom(
                backgroundColor: KairosPalette.primary,
              ),
              icon: _searchingCandidates
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(
                _searchingCandidates ? 'Buscando...' : 'Buscar candidatos',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMatchResults() {
    if (!_hasSearchedCandidates) {
      return const KCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Selecciona una o más competencias y presiona "Buscar candidatos" para ver '
            'estudiantes que calzan con lo que buscas.',
            style: TextStyle(color: KairosPalette.secondary),
          ),
        ),
      );
    }

    if (_searchingCandidates) {
      return Semantics(
        liveRegion: true,
        container: true,
        label: 'Buscando candidatos',
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_candidates.isEmpty) {
      return const KCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'No encontramos estudiantes visibles en Quick Match con esas competencias.',
            style: TextStyle(color: KairosPalette.secondary),
          ),
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_candidates.length} candidato${_candidates.length == 1 ? '' : 's'} '
              'encontrado${_candidates.length == 1 ? '' : 's'}, ordenados por coincidencia',
              style: const TextStyle(
                color: KairosPalette.secondary,
                fontSize: 13,
              ),
            ),
          ),
        ),
        ..._candidates.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _candidateCard(c),
          ),
        ),
      ],
    );
  }

  Widget _candidateCard(Map<String, dynamic> candidate) {
    final id = candidate['id'] as int;
    final fullName = candidate['fullName'] as String? ?? 'Estudiante';
    final institution = candidate['institution'] as String?;
    final avatarUrl = (candidate['profilePictureUrl'] as String? ?? '').trim();
    final matchPercentage = candidate['matchPercentage'] as int? ?? 0;
    final matched = (candidate['matchedSkills'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final missing = (candidate['missingSkills'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final contacting = _contactingIds.contains(id);
    final contacted = _contactedIds.contains(id);

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      backgroundColor: KairosPalette.muted,
                      child: avatarUrl.isEmpty
                          ? Text(
                              fullName.isNotEmpty
                                  ? fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          if (institution != null && institution.isNotEmpty)
                            Text(
                              institution,
                              style: const TextStyle(
                                color: KairosPalette.secondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$matchPercentage%',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: KairosPalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: matchPercentage / 100,
              minHeight: 6,
              backgroundColor: KairosPalette.muted,
              color: KairosPalette.primary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...matched.map(
                (s) => Chip(
                  label: Text(
                    s['name'] as String,
                    style: const TextStyle(fontSize: 12),
                  ),
                  side: BorderSide.none,
                  backgroundColor: KairosPalette.primary.withValues(
                    alpha: 0.12,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              ...missing.map(
                (s) => Chip(
                  label: Text(
                    s['name'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      color: KairosPalette.secondary,
                    ),
                  ),
                  side: BorderSide.none,
                  backgroundColor: KairosPalette.muted,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: contacted
                ? OutlinedButton.icon(
                    onPressed: () => widget.onOpenChat?.call(id.toString()),
                    icon: const Icon(
                      Icons.chat_bubble_rounded,
                      size: 16,
                      color: KairosPalette.primary,
                    ),
                    label: const Text('Contactado · ver chat'),
                  )
                : ElevatedButton.icon(
                    onPressed: contacting
                        ? null
                        : () => _contactCandidate(candidate),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KairosPalette.accent,
                    ),
                    icon: contacting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(contacting ? 'Enviando...' : 'Contactar'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({
    required this.logoUrl,
    required this.company,
    required this.size,
  });
  final String logoUrl;
  final String company;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: 'Logo de $company',
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: KairosPalette.muted,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Text(
          company.isNotEmpty ? company[0].toUpperCase() : '?',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.45),
        ),
      ),
    );
  }
}
