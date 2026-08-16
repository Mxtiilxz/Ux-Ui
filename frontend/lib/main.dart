import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/analytics/analytics.dart';
import 'core/api/api_client.dart';
import 'core/api/demo_backend.dart';
import 'core/models/user_profile.dart';
import 'core/services/social_hub_service.dart';
import 'core/state/user_role_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/pending_approval_page.dart';
import 'features/chat/presentation/pages/chats_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/jobs/presentation/pages/jobs_page.dart';
import 'features/network/presentation/pages/network_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';

void main() {
  runApp(const KairosApp());
}

class KairosApp extends StatefulWidget {
  const KairosApp({super.key});

  @override
  State<KairosApp> createState() => _KairosAppState();
}

class _KairosAppState extends State<KairosApp> {
  late final SemanticsHandle _semanticsHandle;
  UserProfile? _currentUser;
  final UserRoleController _roleController = UserRoleController();
  int _selectedIndex = 0;
  bool _restoringSession = true;
  String? _initialChatContactId;

  /// Credenciales de una cuenta que existe pero espera aprobación. Se guardan
  /// solo en memoria y solo mientras dura la espera, para poder reintentar el
  /// acceso sin volver a pedirlas.
  ({String email, String password})? _awaitingApproval;

  // Notificaciones sociales en vivo. El shell las publica en una región
  // `liveRegion`, así que un lector de pantalla las anuncia sin robar el foco
  // (WCAG 4.1.3). Se limpian solas para no dejar el mensaje colgado.
  SocialHubService? _socialHub;
  final List<StreamSubscription<Map<String, dynamic>>> _hubSubscriptions = [];
  Timer? _liveNotificationTimer;
  String? _liveNotification;

  void _openChatWith(String userId) {
    setState(() {
      _selectedIndex = 3;
      _initialChatContactId = userId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _initialChatContactId = null);
    });
  }

  @override
  void initState() {
    super.initState();
    // Retain the handle for the app lifetime. If it is discarded immediately,
    // Flutter Web can fall back to a pointer-only "Enable accessibility"
    // affordance instead of exposing the initial semantics tree.
    _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    final api = ApiClient();
    final token = await api.getToken();
    if (token != null) {
      final profile = await api.loadProfile();
      if (profile != null && mounted) {
        final roleStr = profile['role'] ?? 'student';
        final role = switch (roleStr) {
          'staff' => UserRole.staff,
          'company' => UserRole.company,
          'alumni' => UserRole.alumni,
          _ => UserRole.student,
        };
        final user = UserProfile(
          id: profile['id'] ?? '',
          name: profile['fullName'] ?? '',
          role: role,
          title: profile['title'] ?? '',
          avatarUrl: profile['profilePictureUrl'] ?? '',
          institution: profile['institution'],
          skills: const [],
          bio: '',
          location: '',
          connections: 0,
          quickMatchVisible: profile['quickMatchVisible'] == 'true',
        );
        _roleController.setRole(role);
        setState(() => _currentUser = user);
        await _connectSocialHub();
      }
    }
    if (mounted) setState(() => _restoringSession = false);
  }

  @override
  void dispose() {
    _liveNotificationTimer?.cancel();
    _disconnectSocialHub();
    _semanticsHandle.dispose();
    _roleController.dispose();
    super.dispose();
  }

  // ── Notificaciones sociales en vivo ────────────────────────────────────────

  /// Conecta el hub social de la sesión actual. En modo demo `connect()` no
  /// hace nada, así que la suscripción queda inerte en vez de fallar.
  Future<void> _connectSocialHub() async {
    if (kDemoMode || _socialHub != null) return;
    final token = await ApiClient().getToken();
    if (token == null || !mounted) return;

    final hub = SocialHubService(token);
    _socialHub = hub;
    SocialHubService.current = hub;
    _hubSubscriptions.addAll([
      hub.onLike.listen((event) {
        final who = event['likedByName'] as String? ?? 'Alguien';
        _announce('$who indicó que le gusta tu publicación.');
      }),
      hub.onFollow.listen((event) {
        final who = event['followerName'] as String? ?? 'Alguien';
        _announce('$who empezó a seguirte.');
      }),
      hub.onComment.listen((_) {
        _announce('Hay un comentario nuevo en la publicación que sigues.');
      }),
    ]);

    try {
      await hub.connect();
    } catch (_) {
      // Sin tiempo real la app sigue siendo usable: el feed se refresca al
      // recargar. No se muestra error porque no hay nada que el usuario pueda
      // hacer al respecto.
    }
  }

  void _disconnectSocialHub() {
    for (final subscription in _hubSubscriptions) {
      subscription.cancel();
    }
    _hubSubscriptions.clear();
    _socialHub?.dispose();
    if (identical(SocialHubService.current, _socialHub)) {
      SocialHubService.current = null;
    }
    _socialHub = null;
  }

  void _announce(String message) {
    if (!mounted) return;
    setState(() => _liveNotification = message);
    _liveNotificationTimer?.cancel();
    _liveNotificationTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _liveNotification = null);
    });
  }

  /// La cuenta que esperaba fue aprobada: se completa la sesión con la
  /// respuesta del login que consiguió la pantalla de espera, sin pedirle nada
  /// más al usuario.
  Future<void> _onApproved(Map<String, dynamic> response) async {
    final api = ApiClient();
    final token = response['token'] as String? ?? '';
    if (token.isEmpty) return;

    final roleStr = response['role'] as String? ?? 'student';
    final role = switch (roleStr) {
      'staff' => UserRole.staff,
      'company' => UserRole.company,
      'alumni' => UserRole.alumni,
      _ => UserRole.student,
    };
    final institution = response['institution'] as String?;

    await api.saveToken(token);
    await api.saveProfile({
      'id': (response['userId'] as int? ?? 0).toString(),
      'fullName': response['fullName'] as String? ?? '',
      'role': roleStr,
      'title': '',
      'profilePictureUrl': response['profilePictureUrl'] as String? ?? '',
      'institution': institution,
    });

    if (!mounted) return;
    setState(() => _awaitingApproval = null);

    _onLoginSuccess(
      UserProfile(
        id: (response['userId'] as int? ?? 0).toString(),
        name: response['fullName'] as String? ?? '',
        role: role,
        title: '',
        avatarUrl: response['profilePictureUrl'] as String? ?? '',
        skills: const [],
        bio: '',
        location: '',
        connections: 0,
        institution: institution,
        quickMatchVisible: response['quickMatchVisible'] as bool? ?? false,
      ),
    );
  }

  void _onLoginSuccess(UserProfile user) {
    _roleController.setRole(user.role);
    setState(() {
      _currentUser = user;
      _selectedIndex = 0;
    });
    _connectSocialHub();
  }

  Future<void> _onLogout() async {
    Analytics.logout();
    _liveNotificationTimer?.cancel();
    _disconnectSocialHub();
    await ApiClient().clearToken();
    if (kDemoMode) DemoBackend.instance.reset();
    setState(() {
      _currentUser = null;
      _liveNotification = null;
    });
  }

  static const _tabNames = ['inicio', 'trabajos', 'red', 'chats', 'perfil'];
  static const _tabTitles = ['Inicio', 'Trabajos', 'Red', 'Chats', 'Perfil'];

  String get _pageTitle {
    if (_restoringSession) return 'Kairos — Cargando';
    if (_awaitingApproval != null) return 'Kairos — Cuenta en espera';
    if (_currentUser == null) return 'Kairos — Iniciar sesión';
    final title = _selectedIndex >= 0 && _selectedIndex < _tabTitles.length
        ? _tabTitles[_selectedIndex]
        : 'Inicio';
    return 'Kairos — $title';
  }

  void _onSelectTab(int index) {
    if (index >= 0 && index < _tabNames.length) {
      Analytics.tabView(_tabNames[index]);
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kairos',
      onGenerateTitle: (_) => _pageTitle,
      locale: const Locale('es', 'CL'),
      supportedLocales: const [Locale('es', 'CL')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _restoringSession
          ? Semantics(
              liveRegion: true,
              label: 'Cargando sesión',
              child: Scaffold(body: Center(child: CircularProgressIndicator())),
            )
          : _awaitingApproval != null
          ? PendingApprovalPage(
              email: _awaitingApproval!.email,
              password: _awaitingApproval!.password,
              onApproved: _onApproved,
              onCancel: () => setState(() => _awaitingApproval = null),
            )
          : _currentUser == null
          ? LoginPage(
              onLoginSuccess: _onLoginSuccess,
              onPendingApproval: (email, password) => setState(
                () => _awaitingApproval = (email: email, password: password),
              ),
            )
          : AnimatedBuilder(
              animation: _roleController,
              builder: (context, _) {
                return AppShell(
                  selectedIndex: _selectedIndex,
                  onSelectIndex: _onSelectTab,
                  currentUser: _currentUser!,
                  roleController: _roleController,
                  onLogout: _onLogout,
                  liveNotification: _liveNotification,
                  child: _buildScreen(),
                );
              },
            ),
    );
  }

  Widget _buildScreen() {
    switch (_selectedIndex) {
      case 0:
        return HomePage(currentUser: _currentUser!, role: _roleController.role);
      case 1:
        return JobsPage(
          role: _roleController.role,
          currentUser: _currentUser!,
          onOpenChat: _openChatWith,
        );
      case 2:
        return const NetworkPage();
      case 3:
        return ChatsPage(
          currentUser: _currentUser!,
          initialContactId: _initialChatContactId,
        );
      case 4:
        return ProfilePage(
          currentUser: _currentUser!,
          activeRole: _roleController.role,
        );
      default:
        return HomePage(currentUser: _currentUser!, role: _roleController.role);
    }
  }
}
