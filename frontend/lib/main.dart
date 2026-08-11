import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/analytics/analytics.dart';
import 'core/api/api_client.dart';
import 'core/api/demo_backend.dart';
import 'core/models/user_profile.dart';
import 'core/state/user_role_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'features/auth/presentation/pages/login_page.dart';
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
      }
    }
    if (mounted) setState(() => _restoringSession = false);
  }

  @override
  void dispose() {
    _semanticsHandle.dispose();
    _roleController.dispose();
    super.dispose();
  }

  void _onLoginSuccess(UserProfile user) {
    _roleController.setRole(user.role);
    setState(() {
      _currentUser = user;
      _selectedIndex = 0;
    });
  }

  Future<void> _onLogout() async {
    Analytics.logout();
    await ApiClient().clearToken();
    if (kDemoMode) DemoBackend.instance.reset();
    setState(() => _currentUser = null);
  }

  static const _tabNames = ['inicio', 'trabajos', 'red', 'chats', 'perfil'];
  static const _tabTitles = ['Inicio', 'Trabajos', 'Red', 'Chats', 'Perfil'];

  String get _pageTitle {
    if (_restoringSession) return 'Kairos — Cargando';
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
          : _currentUser == null
          ? LoginPage(onLoginSuccess: _onLoginSuccess)
          : AnimatedBuilder(
              animation: _roleController,
              builder: (context, _) {
                return AppShell(
                  selectedIndex: _selectedIndex,
                  onSelectIndex: _onSelectTab,
                  currentUser: _currentUser!,
                  roleController: _roleController,
                  onLogout: _onLogout,
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
