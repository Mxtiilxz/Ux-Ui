import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../state/user_role_controller.dart';
import '../theme/kairos_palette.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onSelectIndex,
    required this.currentUser,
    required this.roleController,
    required this.onLogout,
    required this.child,
    this.liveNotification,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectIndex;
  final UserProfile currentUser;
  final UserRoleController roleController;
  final VoidCallback onLogout;
  final Widget child;
  final String? liveNotification;

  static const List<_NavItem> _navItems = [
    _NavItem(label: 'Inicio', icon: Icons.home_rounded),
    _NavItem(label: 'Trabajos', icon: Icons.work_rounded),
    _NavItem(label: 'Red', icon: Icons.group_rounded),
    _NavItem(label: 'Chats', icon: Icons.chat_bubble_rounded),
    _NavItem(label: 'Perfil', icon: Icons.person_rounded),
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final FocusNode _mainFocusNode = FocusNode(debugLabel: 'Kairos main content');

  int get selectedIndex => widget.selectedIndex;
  ValueChanged<int> get onSelectIndex => widget.onSelectIndex;
  UserProfile get currentUser => widget.currentUser;
  UserRoleController get roleController => widget.roleController;
  VoidCallback get onLogout => widget.onLogout;
  Widget get child => widget.child;
  String? get liveNotification => widget.liveNotification;

  @override
  void initState() {
    super.initState();
    _mainFocusNode.addListener(_handleMainFocusChange);
  }

  void _handleMainFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mainFocusNode.removeListener(_handleMainFocusChange);
    _mainFocusNode.dispose();
    super.dispose();
  }

  void _focusMainContent() {
    _mainFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 960;
    final compactDesktop = width < 1320;
    final avatarUrl = currentUser.avatarUrl.trim();

    final mainRegion = Semantics(
      container: true,
      explicitChildNodes: true,
      focusable: true,
      focused: _mainFocusNode.hasFocus,
      label: 'Contenido principal',
      onFocus: _focusMainContent,
      child: Focus(
        focusNode: _mainFocusNode,
        includeSemantics: false,
        child: child,
      ),
    );

    final header = isMobile
        ? _MobileHeader(
            currentUser: currentUser,
            onLogout: () => _confirmLogout(context),
            onSkipToMain: _focusMainContent,
          )
        : _DesktopHeader(
            currentUser: currentUser,
            compactDesktop: compactDesktop,
            avatarUrl: avatarUrl,
            selectedIndex: selectedIndex,
            onSelectIndex: onSelectIndex,
            onLogout: () => _confirmLogout(context),
            onSkipToMain: _focusMainContent,
          );

    final body = Column(
      children: [
        header,
        if (liveNotification != null) _LiveBanner(text: liveNotification!),
        Expanded(child: mainRegion),
      ],
    );

    return Scaffold(
      body: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Aplicación Kairos',
        child: body,
      ),
      bottomNavigationBar: isMobile
          ? Semantics(
              container: true,
              explicitChildNodes: true,
              label: 'Navegación principal',
              child: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelectIndex,
                destinations: AppShell._navItems
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.icon),
                        label: item.label,
                      ),
                    )
                    .toList(growable: false),
              ),
            )
          : null,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KairosPalette.danger,
              minimumSize: const Size(48, 48),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onLogout();
            },
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.currentUser,
    required this.onLogout,
    required this.onSkipToMain,
  });

  final UserProfile currentUser;
  final VoidCallback onLogout;
  final VoidCallback onSkipToMain;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Semantics(
        header: true,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Encabezado principal',
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: KairosPalette.border, width: 1.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _Brand(onSkipToMain: onSkipToMain),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          currentUser.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: KairosPalette.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.currentUser,
    required this.compactDesktop,
    required this.avatarUrl,
    required this.selectedIndex,
    required this.onSelectIndex,
    required this.onLogout,
    required this.onSkipToMain,
  });

  final UserProfile currentUser;
  final bool compactDesktop;
  final String avatarUrl;
  final int selectedIndex;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onLogout;
  final VoidCallback onSkipToMain;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Encabezado principal',
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: KairosPalette.border, width: 1.2),
            ),
          ),
          child: Row(
            children: [
              _Brand(onSkipToMain: onSkipToMain),
              if (!compactDesktop) ...[
                const SizedBox(width: 12),
                Text(
                  currentUser.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: KairosPalette.foreground,
                  ),
                ),
              ],
              const SizedBox(width: 16),
              SizedBox(
                width: compactDesktop ? 220 : 320,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Buscar',
                    hintText: 'Buscar...',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: KairosPalette.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: KairosPalette.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      label: 'Navegación principal',
                      child: Row(
                        children: [
                          Wrap(
                            spacing: 6,
                            children: List.generate(
                              AppShell._navItems.length,
                              (index) => _DesktopNavItem(
                                item: AppShell._navItems[index],
                                active: selectedIndex == index,
                                compact: compactDesktop,
                                onTap: () => onSelectIndex(index),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            tooltip: 'Cerrar sesión',
                            onPressed: onLogout,
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: KairosPalette.secondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Semantics(
                            image: true,
                            label: avatarUrl.isEmpty
                                ? 'Avatar de ${currentUser.name}'
                                : 'Foto de perfil de ${currentUser.name}',
                            child: CircleAvatar(
                              radius: 16,
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? const Icon(Icons.person_rounded, size: 16)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.item,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final _NavItem item;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = compact
        ? IconButton(
            tooltip: item.label,
            onPressed: onTap,
            icon: Icon(item.icon),
            color: active ? KairosPalette.primary : KairosPalette.secondary,
          )
        : TextButton.icon(
            onPressed: onTap,
            icon: Icon(item.icon),
            label: Text(item.label),
            style: TextButton.styleFrom(
              foregroundColor: active
                  ? KairosPalette.primary
                  : KairosPalette.secondary,
              backgroundColor: active
                  ? KairosPalette.muted
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );

    return Semantics(
      button: true,
      selected: active,
      container: true,
      explicitChildNodes: true,
      excludeSemantics: true,
      label: item.label,
      hint: active ? 'Sección seleccionada' : 'Ir a ${item.label}',
      onTap: onTap,
      child: button,
    );
  }
}

// ── Live notification banner ───────────────────────────────────────────────────

class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 300),
      color: KairosPalette.primary.withValues(alpha: 0.9),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Semantics(
        liveRegion: true,
        container: true,
        explicitChildNodes: true,
        label: text,
        child: ExcludeSemantics(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _Brand extends StatefulWidget {
  const _Brand({required this.onSkipToMain});

  final VoidCallback onSkipToMain;

  @override
  State<_Brand> createState() => _BrandState();
}

class _BrandState extends State<_Brand> {
  late final FocusNode _brandFocusNode = FocusNode(
    debugLabel: 'Kairos brand skip control',
  );

  @override
  void dispose() {
    _brandFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'Kairos, saltar al contenido principal',
      hint: 'Activa para mover el foco al contenido principal',
      onTap: widget.onSkipToMain,
      child: TextButton(
        key: const ValueKey('kairos-brand-skip'),
        focusNode: _brandFocusNode,
        onPressed: widget.onSkipToMain,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          alignment: Alignment.centerLeft,
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [KairosPalette.primary, KairosPalette.accent],
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.bolt_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              'Kairos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: KairosPalette.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}
