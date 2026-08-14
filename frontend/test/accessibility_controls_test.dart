import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/core/widgets/post_card.dart';
import 'package:frontend/features/auth/presentation/pages/login_page.dart';
import 'package:frontend/features/auth/presentation/pages/register_page.dart';
import 'package:frontend/features/home/data/models/post_model.dart';
import 'package:frontend/features/profile/presentation/pages/profile_page.dart';

Widget _viewport(Widget child, {double textScale = 1}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(320, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: SizedBox(width: 320, height: 800, child: child),
    ),
  );
}

void main() {
  testWidgets(
    'login fields have persistent labels and contextual password action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_viewport(LoginPage(onLoginSuccess: (_) {})));

      expect(find.bySemanticsLabel('Correo o usuario'), findsOneWidget);
      expect(find.bySemanticsLabel('Contraseña'), findsOneWidget);
      expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('registration roles expose selected state and labeled fields', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _viewport(RegisterPage(onRegisterSuccess: (_, _) {})),
    );

    final selected = tester.getSemantics(
      find.bySemanticsLabel(RegExp('^Estudiante')),
    );
    expect(
      selected,
      matchesSemantics(
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(find.bySemanticsLabel('Nombre completo'), findsOneWidget);
    expect(find.bySemanticsLabel('Correo electrónico'), findsOneWidget);
    expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);
    expect(
      find.byTooltip('Mostrar confirmación de contraseña'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('login and registration reflow at 320px and 200% text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _viewport(LoginPage(onLoginSuccess: (_) {}), textScale: 2),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _viewport(RegisterPage(onRegisterSuccess: (_, _) {}), textScale: 2),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration role group supports keyboard arrow selection', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _viewport(RegisterPage(onRegisterSuccess: (_, _) {})),
    );

    final staffTileFinder = find.byWidgetPredicate(
      (widget) => widget is RadioListTile<String> && widget.value == 'staff',
    );
    final staffTile = tester.widget<RadioListTile<String>>(staffTileFinder);
    staffTile.focusNode!.requestFocus();
    await tester.pump();
    expect(staffTile.focusNode!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('^Empresa'))),
      matchesSemantics(
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        isFocused: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('Quick Match switch exposes label, state, and actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickMatchVisibilitySwitch(value: false, onChanged: (_) {}),
        ),
      ),
    );

    final toggle = tester.getSemantics(
      find.bySemanticsLabel('Visibilidad en Quick Match'),
    );
    expect(
      toggle,
      matchesSemantics(
        label: 'Visibilidad en Quick Match',
        hasToggledState: true,
        isToggled: false,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('post media and actions expose useful semantics', (tester) async {
    final semantics = tester.ensureSemantics();

    final post = PostModel(
      id: '1',
      author: UserProfile(
        id: '2',
        name: 'Diego Soto',
        role: UserRole.student,
        title: 'Estudiante',
        avatarUrl: '',
        skills: [],
        bio: '',
        location: '',
        connections: 0,
      ),
      content:
          'Proyecto de automatización para el taller. Este texto describe '
          'los sensores, el circuito, las pruebas y los resultados del '
          'prototipo para ofrecer contexto suficiente a quien lee la publicación.',
      likes: 2,
      comments: 0,
      shares: 0,
      timestamp: 'Ahora',
    );

    // Sin descripción del autor la imagen es decorativa: el lector de pantalla
    // no debe repetir el cuerpo del post como texto alternativo.
    expect(post.imageSemanticLabel, isNull);
    expect(
      post
          .copyWith(imageAltText: '  Brazo robótico soldando una pieza  ')
          .imageSemanticLabel,
      'Brazo robótico soldando una pieza',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PostCard(post: post, currentUserId: '2'),
          ),
        ),
      ),
    );

    expect(find.byType(PostCard), findsOneWidget);
    expect(find.bySemanticsLabel('Me gusta'), findsOneWidget);
    expect(find.bySemanticsLabel('Comentar'), findsOneWidget);
    expect(find.bySemanticsLabel('Compartir'), findsOneWidget);
    expect(find.byTooltip('Más opciones para la publicación'), findsOneWidget);
    final expandTarget = tester.getSize(
      find.widgetWithText(TextButton, 'Ver más'),
    );
    expect(expandTarget.height, greaterThanOrEqualTo(48));
    semantics.dispose();
  });

  testWidgets('la imagen de una publicación solo se anuncia si tiene alt', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    PostModel postWith({String? alt}) => PostModel(
      id: '1',
      author: const UserProfile(
        id: '2',
        name: 'Diego Soto',
        role: UserRole.student,
        title: 'Estudiante',
        avatarUrl: '',
        skills: [],
        bio: '',
        location: '',
        connections: 0,
      ),
      content: 'Prototipo terminado.',
      imageUrl: 'https://example.invalid/foto.jpg',
      imageAltText: alt,
      likes: 0,
      comments: 0,
      shares: 0,
      timestamp: 'Ahora',
    );

    Future<void> pump(PostModel post) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PostCard(post: post, currentUserId: '2'),
            ),
          ),
        ),
      );
      // En un test no hay red: Image.network falla y eso no es lo que se está
      // midiendo acá, así que se descarta el error de carga.
      tester.takeException();
    }

    // Sin descripción: la imagen queda fuera del árbol de semántica en vez de
    // heredar el cuerpo de la publicación como texto alternativo.
    await pump(postWith());
    expect(find.bySemanticsLabel('Prototipo terminado.'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(
      tester
          .widgetList<ExcludeSemantics>(find.byType(ExcludeSemantics))
          .where((w) => w.excluding),
      isNotEmpty,
    );

    // Con descripción: se anuncia exactamente lo que escribió el autor.
    await pump(postWith(alt: 'Brazo robótico soldando una pieza'));
    expect(
      find.bySemanticsLabel('Brazo robótico soldando una pieza'),
      findsOneWidget,
    );

    semantics.dispose();
  });
}
