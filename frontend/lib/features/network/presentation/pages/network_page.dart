import 'package:flutter/material.dart';

import '../../../../core/analytics/analytics.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/services/social_hub_service.dart';
import '../../../../core/theme/kairos_palette.dart';
import '../../../../core/widgets/k_card.dart';

class NetworkPage extends StatefulWidget {
  const NetworkPage({super.key});

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  final TextEditingController _searchController = TextEditingController();

  /// Estado de la relación con cada persona: `none`, `pending_sent`,
  /// `pending_received` o `connected`.
  ///
  /// Reemplaza al conjunto de "seguidos" que había antes: con solicitudes de
  /// por medio, sí/no dejaba fuera los dos estados intermedios y el botón no
  /// podía saber qué ofrecer.
  final Map<String, String> _status = <String, String>{};

  final _api = ApiClient();
  List<UserProfile> _apiSuggestions = [];

  /// Solicitudes recibidas sin responder.
  List<Map<String, dynamic>> _requests = [];

  /// Contactos ya conectados.
  List<UserProfile> _connections = [];

  bool _loading = true;

  /// Qué partes de la pantalla no se pudieron cargar. Se guarda el nombre de
  /// cada una en vez de un único booleano para poder decir qué falló: "no se
  /// pudo cargar la red" no distingue entre las sugerencias, las solicitudes y
  /// los contactos, y sin esa distinción no hay por dónde empezar a mirar.
  final Set<String> _failed = <String>{};

  bool get _error => _failed.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _failed.clear();
      });
    }

    // Las tres consultas se resuelven por separado a propósito. Antes iban en
    // un solo `Future.wait`, así que si una fallaba se perdían también las dos
    // que habían respondido bien y la pantalla entera quedaba en cero.
    final suggestions = await _tryLoad(
      'las sugerencias',
      () async => (await _api.getNetworkSuggestions())
          .cast<Map<String, dynamic>>()
          .map(_toProfile)
          .toList(),
    );

    final requests = await _tryLoad(
      'las solicitudes',
      () async => await _api.getConnectionRequests(),
    );

    final connections = await _tryLoad(
      'tus contactos',
      () async =>
          (await _api.getConnections()).map(_toProfile).toList(),
    );

    if (!mounted) return;
    setState(() {
      if (suggestions != null) _apiSuggestions = suggestions;
      if (requests != null) {
        _requests = requests;
        for (final request in requests) {
          _status[request['id'].toString()] = 'pending_received';
        }
      }
      if (connections != null) {
        _connections = connections;
        for (final contact in connections) {
          _status[contact.id] = 'connected';
        }
      }
      _loading = false;
    });
  }

  /// Ejecuta [load] y devuelve `null` si falla, anotando [nombre] entre las
  /// partes que no cargaron.
  Future<T?> _tryLoad<T>(String nombre, Future<T> Function() load) async {
    try {
      return await load();
    } catch (_) {
      _failed.add(nombre);
      return null;
    }
  }

  /// "No se pudieron cargar las sugerencias y tus contactos."
  String _errorMessage() {
    final partes = _failed.toList();
    final lista = partes.length == 1
        ? partes.single
        : '${partes.take(partes.length - 1).join(', ')} y ${partes.last}';
    return 'No se pudieron cargar $lista. Intenta de nuevo.';
  }

  UserProfile _toProfile(Map<String, dynamic> json) {
    final roleStr = (json['role'] as String? ?? 'student').toLowerCase();
    final role = switch (roleStr) {
      'staff' => UserRole.staff,
      'company' => UserRole.company,
      'alumni' => UserRole.alumni,
      _ => UserRole.student,
    };

    final id = json['id'].toString();
    final status = json['connectionStatus'] as String?;
    if (status != null && status != 'none') _status[id] = status;

    return UserProfile(
      id: id,
      name: json['fullName'] as String? ?? 'Usuario',
      role: role,
      title: (json['title'] ?? json['institution']) as String? ?? '',
      avatarUrl:
          (json['avatarUrl'] ?? json['profilePictureUrl']) as String? ?? '',
      skills: const [],
      bio: json['bio'] as String? ?? '',
      location: json['location'] as String? ?? '',
      connections: (json['followersCount'] as num?)?.toInt() ?? 0,
    );
  }

  String _statusOf(String userId) => _status[userId] ?? 'none';

  /// Envía la solicitud, o la deshace si ya existía. Conectar deja de ser
  /// inmediato: hasta que la otra persona acepte, la relación queda en espera.
  Future<void> _toggleConnection(UserProfile user) async {
    final userId = int.tryParse(user.id);
    if (userId == null) return;

    final previous = _statusOf(user.id);
    final isUndo = previous == 'connected' || previous == 'pending_sent';

    setState(() => _status[user.id] = isUndo ? 'none' : 'pending_sent');

    try {
      if (isUndo) {
        await _api.removeConnection(userId);
        Analytics.follow(false);
        if (mounted) {
          setState(() => _connections.removeWhere((c) => c.id == user.id));
        }
      } else {
        final result = await _api.requestConnection(userId);
        Analytics.follow(true);
        await SocialHubService.current?.notifyFollow(user.id);
        if (!mounted) return;
        setState(() => _status[user.id] = result);
        // El servidor puede responder "connected" si esa persona ya había
        // solicitado conectar: entonces el contacto entra en la lista.
        if (result == 'connected') await _loadAll();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status[user.id] = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar la conexión.'),
            backgroundColor: KairosPalette.danger,
          ),
        );
      }
    }
  }

  Future<void> _respondToRequest(
    Map<String, dynamic> request, {
    required bool accept,
  }) async {
    final userId = request['id'] as int;
    setState(() => _requests.removeWhere((r) => r['id'] == userId));

    try {
      await _api.respondToConnectionRequest(userId, accept: accept);
      await _loadAll();
    } catch (_) {
      if (mounted) {
        setState(() => _requests = [..._requests, request]);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo responder la solicitud.'),
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
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 760;
    final pagePadding = mobile
        ? const EdgeInsets.fromLTRB(14, 14, 14, 16)
        : const EdgeInsets.all(20);
    final query = _searchController.text.trim().toLowerCase();
    final visible = _apiSuggestions
        .where((u) {
          if (query.isEmpty) return true;
          return u.name.toLowerCase().contains(query) ||
              u.title.toLowerCase().contains(query) ||
              u.skills.any((skill) => skill.toLowerCase().contains(query));
        })
        .toList(growable: false);

    return SingleChildScrollView(
      padding: pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu Red Profesional',
            style: TextStyle(
              fontSize: mobile ? 26 : 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Conecta con profesionales tecnicos y amplia tus oportunidades.',
          ),
          const SizedBox(height: 16),
          KCard(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Buscar personas',
                hintText: 'Buscar por nombre, oficio o habilidad...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (mobile)
            Column(
              children: [
                _stats(
                  Icons.people_alt_rounded,
                  // Antes se le sumaba 234 a este número, sin más motivo que
                  // hacer parecer poblada una red que estaba vacía.
                  '${_connections.length}',
                  'Conexiones totales',
                ),
                const SizedBox(height: 10),
                _stats(
                  Icons.person_add_alt_1_rounded,
                  '${visible.length}',
                  'Sugerencias para ti',
                ),
              ],
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 900;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: wide ? 2 : 1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3,
                  children: [
                    _stats(
                      Icons.people_alt_rounded,
                      '${_connections.length}',
                      'Conexiones totales',
                    ),
                    _stats(
                      Icons.person_add_alt_1_rounded,
                      '${visible.length}',
                      'Sugerencias para ti',
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 12),
          _requestsBubble(),
          _connectionsList(),
          const SizedBox(height: 4),
          const Text(
            'Sugerencias para ti',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_loading)
            Semantics(
              liveRegion: true,
              container: true,
              label: 'Cargando sugerencias de red',
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (_error)
            Semantics(
              liveRegion: true,
              container: true,
              label: _errorMessage(),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Text(_errorMessage(), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadAll,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (visible.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('No hay sugerencias disponibles por ahora.'),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                int cross = 1;
                if (constraints.maxWidth > 1260) {
                  cross = 3;
                } else if (constraints.maxWidth > 760) {
                  cross = 2;
                }

                if (cross == 1) {
                  return Column(
                    children: visible
                        .map(
                          (user) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _networkUserCard(user),
                          ),
                        )
                        .toList(growable: false),
                  );
                }

                return GridView.builder(
                  itemCount: visible.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.88,
                  ),
                  itemBuilder: (context, index) {
                    final user = visible[index];
                    return _networkUserCard(user);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  /// Burbuja de solicitudes recibidas. Muestra las primeras y abre el resto en
  /// una ventana desplazable, para que una bandeja larga no empuje el resto de
  /// la pantalla hacia abajo.
  Widget _requestsBubble() {
    if (_requests.isEmpty) return const SizedBox.shrink();

    const preview = 3;
    final shown = _requests.take(preview).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                label: _requests.length == 1
                    ? 'Tienes 1 solicitud de conexión'
                    : 'Tienes ${_requests.length} solicitudes de conexión',
                child: Row(
                  children: [
                    const Icon(
                      Icons.mark_email_unread_rounded,
                      color: KairosPalette.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _requests.length == 1
                            ? 'Solicitudes de conexión (1)'
                            : 'Solicitudes de conexión (${_requests.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (_requests.length > preview)
                      TextButton(
                        onPressed: _showAllRequests,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        child: Text('Ver las ${_requests.length}'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ...shown.map(_requestRow),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllRequests() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Solicitudes de conexión (${_requests.length})',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 460,
          // Altura acotada y desplazamiento propio: la bandeja puede crecer sin
          // que el diálogo se salga de la pantalla.
          height: 420,
          child: StatefulBuilder(
            builder: (ctx, setInner) => ListView(
              children: _requests
                  .map(
                    (request) => _requestRow(
                      request,
                      onResponded: () => setInner(() {}),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _requestRow(
    Map<String, dynamic> request, {
    VoidCallback? onResponded,
  }) {
    final name = request['fullName'] as String? ?? 'Usuario';
    final institution = request['institution'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: KairosPalette.muted,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (institution != null && institution.isNotEmpty)
                  Text(
                    institution,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KairosPalette.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Aceptar la solicitud de $name',
            onPressed: () {
              _respondToRequest(request, accept: true);
              onResponded?.call();
            },
            icon: const Icon(
              Icons.check_circle_rounded,
              color: KairosPalette.success,
            ),
          ),
          IconButton(
            tooltip: 'Rechazar la solicitud de $name',
            onPressed: () {
              _respondToRequest(request, accept: false);
              onResponded?.call();
            },
            icon: const Icon(Icons.cancel_rounded, color: KairosPalette.danger),
          ),
        ],
      ),
    );
  }

  /// Contactos ya conectados, en lista, debajo de la burbuja de solicitudes.
  Widget _connectionsList() {
    if (_connections.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mis contactos (${_connections.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              ..._connections.map(
                (contact) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: KairosPalette.muted,
                        child: Text(
                          contact.name.isNotEmpty
                              ? contact.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (contact.title.isNotEmpty)
                              Text(
                                contact.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: KairosPalette.mutedForeground,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar a ${contact.name} de mis contactos',
                        onPressed: () => _toggleConnection(contact),
                        icon: const Icon(Icons.person_remove_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stats(IconData icon, String value, String label) {
    return KCard(
      borderColor: KairosPalette.primary.withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: KairosPalette.muted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: KairosPalette.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < 760 ? 26 : 30,
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

  /// Botón de conexión según el estado de la relación.
  Widget _connectionButton(UserProfile user, String status) {
    final (label, icon, filled) = switch (status) {
      'connected' => ('Conectado', Icons.how_to_reg_rounded, false),
      'pending_sent' => (
        'Solicitud enviada',
        Icons.hourglass_top_rounded,
        false,
      ),
      'pending_received' => ('Te solicitó conectar', Icons.mail_rounded, true),
      _ => ('Conectar', Icons.person_add_rounded, true),
    };

    // Una solicitud recibida se responde desde la burbuja de arriba, no desde
    // esta tarjeta: ahí están los dos botones, aceptar y rechazar.
    final onPressed = status == 'pending_received'
        ? null
        : () => _toggleConnection(user);

    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: KairosPalette.accent,
                foregroundColor: Colors.white,
              ),
              icon: Icon(icon, size: 16),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: Icon(icon, size: 16),
              label: Text(label),
            ),
    );
  }

  Widget _networkUserCard(UserProfile user) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    final status = _statusOf(user.id);
    return KCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: mobile ? 62 : 72,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x140F766E), Color(0x0F00B5AD)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: Offset(0, mobile ? -24 : -30),
                  child: ExcludeSemantics(
                    child: CircleAvatar(
                      radius: mobile ? 32 : 36,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: mobile ? 28 : 32,
                        backgroundImage: user.avatarUrl.trim().isNotEmpty
                            ? NetworkImage(user.avatarUrl)
                            : null,
                        child: user.avatarUrl.trim().isEmpty
                            ? const Icon(Icons.person_rounded)
                            : null,
                      ),
                    ),
                  ),
                ),
                Text(
                  user.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: mobile ? 17 : 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: KairosPalette.secondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.pin_drop_rounded,
                      size: 16,
                      color: KairosPalette.secondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        user.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: KairosPalette.secondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  user.bio,
                  maxLines: mobile ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: user.skills
                      .take(mobile ? 2 : 3)
                      .map((skill) {
                        return Chip(
                          label: Text(skill),
                          side: BorderSide.none,
                          backgroundColor: KairosPalette.muted,
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 10),
                Text(
                  '${user.connections} conexiones',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: KairosPalette.primary,
                  ),
                ),
                const SizedBox(height: 10),
                // El botón refleja los cuatro estados posibles. Con un simple
                // "Conectar / Conectado" no había forma de distinguir una
                // solicitud enviada de una conexión real.
                _connectionButton(user, status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
