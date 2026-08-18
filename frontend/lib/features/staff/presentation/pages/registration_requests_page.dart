import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/kairos_palette.dart';
import '../../../../core/widgets/k_card.dart';

class RegistrationRequestsPage extends StatefulWidget {
  const RegistrationRequestsPage({super.key});

  @override
  State<RegistrationRequestsPage> createState() =>
      _RegistrationRequestsPageState();
}

class _RegistrationRequestsPageState extends State<RegistrationRequestsPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  final Set<int> _processing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getRegistrationRequests();
      if (mounted) {
        setState(() => _requests = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar solicitudes.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(int userId) async {
    setState(() => _processing.add(userId));
    try {
      await _api.approveUser(userId);
      if (mounted) {
        setState(() => _requests.removeWhere((r) => r['id'] == userId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta aprobada.'),
            backgroundColor: KairosPalette.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al aprobar.'),
            backgroundColor: KairosPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(userId));
    }
  }

  Future<void> _reject(int userId) async {
    setState(() => _processing.add(userId));
    try {
      await _api.rejectUser(userId);
      if (mounted) {
        setState(() => _requests.removeWhere((r) => r['id'] == userId));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Solicitud rechazada.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al rechazar.'),
            backgroundColor: KairosPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Solicitudes de registro',
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
              label: 'Cargando solicitudes de registro',
              child: Center(child: CircularProgressIndicator()),
            )
          : _requests.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: KairosPalette.success,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay solicitudes pendientes.',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final req = _requests[index];
                final id = req['id'] as int;
                final busy = _processing.contains(id);
                final roleLabel = switch ((req['role'] as String? ?? 'student')
                    .toLowerCase()) {
                  'company' => 'Empresa',
                  'staff' => 'Staff',
                  'alumni' => 'Egresado',
                  _ => 'Estudiante',
                };
                return KCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            label:
                                'Avatar de ${req['fullName'] as String? ?? 'usuario'}',
                            image: true,
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: KairosPalette.muted,
                              child: Text(
                                (req['fullName'] as String? ?? '?')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req['fullName'] as String? ?? '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  req['email'] as String? ?? '-',
                                  style: const TextStyle(
                                    color: KairosPalette.secondary,
                                    fontSize: 13,
                                  ),
                                ),
                                if ((req['institution'] as String?)
                                        ?.isNotEmpty ==
                                    true)
                                  Text(
                                    req['institution'] as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: KairosPalette.secondary,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Chip(
                                  label: Text(
                                    roleLabel,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  side: BorderSide.none,
                                  backgroundColor: KairosPalette.muted,
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (busy)
                        const Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Aprobar solicitud',
                                onPressed: () => _approve(id),
                                icon: const Icon(
                                  Icons.check_circle_rounded,
                                  color: KairosPalette.success,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Rechazar solicitud',
                                onPressed: () => _reject(id),
                                icon: const Icon(
                                  Icons.cancel_rounded,
                                  color: KairosPalette.danger,
                                ),
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
