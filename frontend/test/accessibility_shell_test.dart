import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/core/state/user_role_controller.dart';
import 'package:frontend/core/widgets/app_shell.dart';

UserProfile _user() => const UserProfile(
  id: '1',
  name: 'Camila Vidal',
  role: UserRole.student,
  title: 'Estudiante',
  avatarUrl: '',
  skills: [],
  bio: '',
  location: 'Santiago',
  connections: 0,
);

Widget _shell({String? liveNotification, ValueChanged<int>? onSelectIndex}) {
  return MaterialApp(
    home: AppShell(
      selectedIndex: 0,
      onSelectIndex: onSelectIndex ?? (_) {},
      currentUser: _user(),
      roleController: UserRoleController(),
      onLogout: () {},
      liveNotification: liveNotification,
      child: const ColoredBox(
        color: Colors.white,
        child: Center(child: Text('Inicio de Kairos')),
      ),
    ),
  );
}

SemanticsNode _descendantWithLabel(SemanticsNode node, String label) {
  if (node.label == label || node.label.startsWith('$label\n')) return node;
  for (final child in node.debugListChildrenInOrder(
    DebugSemanticsDumpOrder.traversalOrder,
  )) {
    try {
      return _descendantWithLabel(child, label);
    } on StateError {
      // Continue searching the remaining semantic descendants.
    }
  }
  throw StateError('No semantic node with label "$label" was found.');
}

void main() {
  testWidgets('shell exposes landmarks and selected navigation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_shell());

      expect(find.bySemanticsLabel('Aplicación Kairos'), findsOneWidget);
      expect(find.bySemanticsLabel('Encabezado principal'), findsOneWidget);
      expect(find.bySemanticsLabel('Navegación principal'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Kairos, saltar al contenido principal'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Saltar al contenido principal'),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Contenido principal'), findsOneWidget);

      final navigation = tester.getSemantics(
        find.bySemanticsLabel('Navegación principal'),
      );
      final home = _descendantWithLabel(navigation, 'Inicio');
      expect(home.flagsCollection.isSelected, Tristate.isTrue);

      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'Kairos brand moves focus to main content with keyboard without changing tab',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var selectedTabCalls = 0;
      try {
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _shell(onSelectIndex: (_) => selectedTabCalls++),
        );

        final brand = find.byKey(const ValueKey('kairos-brand-skip'));
        final brandButton = tester.widget<TextButton>(brand);
        for (final key in [
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.space,
        ]) {
          brandButton.focusNode!.requestFocus();
          await tester.pump();
          expect(
            FocusManager.instance.primaryFocus?.debugLabel,
            'Kairos brand skip control',
          );

          await tester.sendKeyEvent(key);
          await tester.pump();

          expect(
            FocusManager.instance.primaryFocus?.debugLabel,
            'Kairos main content',
          );
          final mainRegion = tester.getSemantics(
            find.bySemanticsLabel('Contenido principal'),
          );
          expect(mainRegion.flagsCollection.isFocused, Tristate.isTrue);
        }
        expect(selectedTabCalls, 0);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'live shell notification is announced and remains usable with reduced motion',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(1200, 800),
              disableAnimations: true,
            ),
            child: _shell(liveNotification: 'Nueva notificación'),
          ),
        );
        await tester.pump();

        expect(find.bySemanticsLabel('Nueva notificación'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
