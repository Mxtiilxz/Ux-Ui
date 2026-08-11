import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/analytics/analytics.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/kairos_palette.dart';
import '../../../../core/widgets/k_card.dart';

class CompanyJobsPage extends StatefulWidget {
  const CompanyJobsPage({super.key});

  @override
  State<CompanyJobsPage> createState() => _CompanyJobsPageState();
}

class _CompanyJobsPageState extends State<CompanyJobsPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _postings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getMyJobPostings();
      if (mounted)
        setState(() => _postings = data.cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar tus ofertas.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deletePosting(int jobId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar oferta'),
        content: Text('¿Eliminar "$title"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KairosPalette.danger,
            ),
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
      await _api.deleteJobPosting(jobId);
      if (mounted) {
        setState(() => _postings.removeWhere((p) => p['id'] == jobId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oferta eliminada.'),
            backgroundColor: KairosPalette.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar.'),
            backgroundColor: KairosPalette.danger,
          ),
        );
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> posting) {
    final titleCtrl = TextEditingController(
      text: posting['title'] as String? ?? '',
    );
    final descCtrl = TextEditingController(
      text: posting['description'] as String? ?? '',
    );
    final locationCtrl = TextEditingController(
      text: posting['location'] as String? ?? '',
    );
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool uploadingImg = false;
    String? imageUrl = posting['imageUrl'] as String?;
    final picker = ImagePicker();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text(
            'Editar oferta',
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
                      ),
                      maxLines: 3,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo requerido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(labelText: 'Ubicación'),
                    ),
                    const SizedBox(height: 14),
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl!,
                              height: 110,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              semanticLabel: 'Imagen de la oferta laboral',
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
                                onPressed: () =>
                                    setInner(() => imageUrl = null),
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
                                final img = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );
                                if (img == null) return;
                                setInner(() => uploadingImg = true);
                                try {
                                  final result = await _api.uploadImage(img);
                                  setInner(
                                    () =>
                                        imageUrl = result['cdnUrl'] as String?,
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
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setInner(() => saving = true);
                      try {
                        await _api.updateJobPosting(
                          jobId: posting['id'] as int,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          location: locationCtrl.text.trim(),
                          imageUrl: imageUrl,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                      } catch (_) {
                        setInner(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Error al guardar.'),
                              backgroundColor: KairosPalette.danger,
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

  void _openApplications(Map<String, dynamic> posting) {
    Analytics.jobViewApplicants();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ApplicationsPage(
          jobId: posting['id'] as int,
          jobTitle: posting['title'] as String? ?? 'Oferta',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis ofertas laborales',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? Semantics(
              liveRegion: true,
              container: true,
              label: 'Cargando ofertas laborales',
              child: Center(child: CircularProgressIndicator()),
            )
          : _postings.isEmpty
          ? const Center(child: Text('No has publicado ninguna oferta aún.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _postings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final p = _postings[index];
                final appCount = p['applicationCount'] as int? ?? 0;
                final jobImageUrl = (p['imageUrl'] as String? ?? '').trim();
                return KCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (jobImageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: Image.network(
                            jobImageUrl,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            semanticLabel:
                                'Imagen de la oferta ${p['title'] as String? ?? ''}',
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p['title'] as String? ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Editar',
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: KairosPalette.primary,
                                  ),
                                  onPressed: () => _showEditDialog(p),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  icon: const Icon(
                                    Icons.delete_rounded,
                                    color: KairosPalette.danger,
                                  ),
                                  onPressed: () => _deletePosting(
                                    p['id'] as int,
                                    p['title'] as String? ?? '',
                                  ),
                                ),
                              ],
                            ),
                            if ((p['location'] as String?)?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.pin_drop_rounded,
                                      size: 14,
                                      color: KairosPalette.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      p['location'] as String,
                                      style: const TextStyle(
                                        color: KairosPalette.secondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              p['description'] as String? ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: KairosPalette.secondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Chip(
                                  label: Text(
                                    '$appCount postulante${appCount == 1 ? '' : 's'}',
                                  ),
                                  side: BorderSide.none,
                                  backgroundColor: appCount > 0
                                      ? KairosPalette.primary.withValues(
                                          alpha: 0.12,
                                        )
                                      : KairosPalette.muted,
                                ),
                                const SizedBox(width: 8),
                                if (appCount > 0)
                                  TextButton.icon(
                                    onPressed: () => _openApplications(p),
                                    icon: const Icon(
                                      Icons.people_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Ver postulantes'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ── Applications sub-page ───────────────────────────────────────────────────

class _ApplicationsPage extends StatefulWidget {
  const _ApplicationsPage({required this.jobId, required this.jobTitle});
  final int jobId;
  final String jobTitle;

  @override
  State<_ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<_ApplicationsPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _applications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getJobApplications(widget.jobId);
      if (mounted)
        setState(() => _applications = data.cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar postulantes.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.jobTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? Semantics(
              liveRegion: true,
              container: true,
              label: 'Cargando postulantes',
              child: Center(child: CircularProgressIndicator()),
            )
          : _applications.isEmpty
          ? const Center(
              child: Text('Aún no hay postulantes para esta oferta.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _applications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final app = _applications[index];
                final applicant =
                    app['applicant'] as Map<String, dynamic>? ?? {};
                final avatarUrl =
                    (applicant['profilePictureUrl'] as String? ?? '').trim();
                final appliedAt = DateTime.tryParse(
                  app['createdAt'] as String? ?? '',
                );
                final dateStr = appliedAt != null
                    ? '${appliedAt.day}/${appliedAt.month}/${appliedAt.year}'
                    : '';
                return KCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        backgroundColor: KairosPalette.muted,
                        child: avatarUrl.isEmpty
                            ? Text(
                                (applicant['fullName'] as String? ?? '?')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              applicant['fullName'] as String? ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              applicant['email'] as String? ?? '-',
                              style: const TextStyle(
                                color: KairosPalette.secondary,
                                fontSize: 13,
                              ),
                            ),
                            if ((applicant['institution'] as String?)
                                    ?.isNotEmpty ==
                                true)
                              Text(
                                applicant['institution'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: KairosPalette.secondary,
                                ),
                              ),
                            if (dateStr.isNotEmpty)
                              Text(
                                'Postulado: $dateStr',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: KairosPalette.secondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if ((app['cvUrl'] as String?)?.isNotEmpty == true)
                        IconButton(
                          tooltip: 'Ver CV',
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: KairosPalette.primary,
                          ),
                          onPressed: () {},
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
