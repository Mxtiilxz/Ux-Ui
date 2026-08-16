import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/kairos_palette.dart';
import '../../../../core/widgets/k_card.dart';

/// Historial de altas de la plataforma.
///
/// Un alumno aparece cuando el liceo lo aprueba, no cuando se registra: antes
/// de eso no forma parte de la red y anunciarlo sería prematuro. Una empresa
/// aparece al registrarse, porque entra directo.
class JoinHistoryPage extends StatefulWidget {
  const JoinHistoryPage({super.key});

  @override
  State<JoinHistoryPage> createState() => _JoinHistoryPageState();
}

class _JoinHistoryPageState extends State<JoinHistoryPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await _api.getJoinHistory();
      if (mounted) setState(() => _history = history);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar el historial.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de altas',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar el historial',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading)
              Semantics(
                liveRegion: true,
                container: true,
                label: 'Cargando el historial de altas',
                child: const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              Semantics(
                liveRegion: true,
                container: true,
                label: _error!,
                child: KCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                ),
              )
            else if (_history.isEmpty)
              const KCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Todavía no se ha sumado nadie a la plataforma.'),
                ),
              )
            else
              ..._history.map(_entry),
          ],
        ),
      ),
    );
  }

  Widget _entry(Map<String, dynamic> item) {
    final role = item['role'] as String? ?? 'student';
    final name = item['fullName'] as String? ?? '';
    final joinedAt = DateTime.tryParse(item['joinedAt'] as String? ?? '');

    final (icon, color, verb) = switch (role) {
      'company' => (
        Icons.business_rounded,
        KairosPalette.accent,
        'se unió a la plataforma',
      ),
      'staff' => (
        Icons.manage_accounts_rounded,
        KairosPalette.primary,
        'se sumó al personal',
      ),
      _ => (Icons.school_rounded, KairosPalette.primary, 'se unió a la red'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: ' $verb'),
                        ],
                      ),
                    ),
                    if (item['institution'] != null)
                      Text(
                        item['institution'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: KairosPalette.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              if (joinedAt != null)
                Text(
                  _relative(joinedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: KairosPalette.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relative(DateTime moment) {
    final diff = DateTime.now().toUtc().difference(moment.toUtc());
    if (diff.inMinutes < 1) return 'Recién';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    return 'Hace ${diff.inDays} días';
  }
}
