import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/staff/presentation/pages/staff_management_page.dart';

Widget _syntheticResponsiveFixture(double width) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 900),
        textScaler: TextScaler.linear(2),
      ),
      child: Scaffold(
        body: SizedBox(
          width: width,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gestión accesible', style: TextStyle(fontSize: 24)),
                const SizedBox(height: 12),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Buscar',
                    hintText: 'Nombre o correo',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(onPressed: () {}, child: Text('Aplicar')),
                    OutlinedButton(
                      onPressed: () {},
                      child: Text('Ver detalles'),
                    ),
                    IconButton(
                      tooltip: 'Actualizar resultados',
                      onPressed: () {},
                      icon: Icon(Icons.refresh),
                    ),
                    ChoiceChip(
                      label: Text('Estudiante'),
                      selected: true,
                      onSelected: (_) {},
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'El contenido se reorganiza sin perder información.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final width in <double>[320, 375, 414, 768]) {
    testWidgets(
      'synthetic responsive fixture reflows at ${width.toInt()} px and 200% text',
      (tester) async {
        await tester.pumpWidget(_syntheticResponsiveFixture(width));
        await tester.pumpAndSettle();

        expect(find.text('Gestión accesible'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'StaffManagementPage reflows at ${width.toInt()} px and 200% text',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(2),
              ),
              child: SizedBox(
                width: width,
                height: 900,
                child: const StaffManagementPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gestión de Usuarios'), findsOneWidget);
        expect(find.text('Seleccionar archivo CSV'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Seleccionar archivo CSV'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  // Alcance de este test: comprueba que los controles Material que usa Kairos
  // cumplen tamaño mínimo y etiquetado con el tema por defecto. No recorre
  // pantallas de producción — eso lo cubren los tests de semántica sobre
  // LoginPage, RegisterPage, PostCard, AppShell y StaffManagementPage.
  //
  // Correrlo sobre una pantalla real con `AppTheme.light` no es posible hoy:
  // google_fonts intenta descargar Manrope, falla sin red y lanza una excepción
  // asíncrona que el framework de tests no permite descartar.
  testWidgets(
    'representative controls meet Flutter target and naming guidelines',
    (tester) async {
      await tester.pumpWidget(_syntheticResponsiveFixture(375));
      await tester.pumpAndSettle();

      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(iOSTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );
}
