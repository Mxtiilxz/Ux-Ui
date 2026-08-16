import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/kairos_palette.dart';
import '../../../../core/widgets/k_card.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  List<_CsvRow> _rows = [];
  String _csvRole = 'student';
  bool _isLoading = false;
  List<_ImportResult> _results = [];
  bool _hasImported = false;

  // Columnas esperadas del CSV (en orden)
  static const _expectedHeaders = [
    'rut',
    'nombre_completo',
    'email',
    'curso',
    'especialidad',
    'edad',
  ];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final content = utf8.decode(bytes);
    _parseCsv(content);
  }

  void _parseCsv(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      _showError('El archivo está vacío.');
      return;
    }

    // Detectar si la primera línea es encabezado
    final firstCols = lines.first
        .split(',')
        .map((c) => c.trim().toLowerCase())
        .toList();
    final hasHeader = _expectedHeaders.any((h) => firstCols.contains(h));
    final dataLines = hasHeader ? lines.skip(1).toList() : lines;

    final rows = <_CsvRow>[];
    for (final line in dataLines) {
      final cols = line.split(',').map((c) => c.trim()).toList();
      if (cols.length < 3) continue; // mínimo rut, nombre, email
      rows.add(
        _CsvRow(
          rut: cols.elementAtOrNull(0) ?? '',
          nombreCompleto: cols.elementAtOrNull(1) ?? '',
          email: cols.elementAtOrNull(2) ?? '',
          curso: cols.elementAtOrNull(3) ?? '',
          especialidad: cols.elementAtOrNull(4) ?? '',
          edad: cols.elementAtOrNull(5) ?? '',
        ),
      );
    }

    setState(() {
      _rows = rows;
      _results = [];
      _hasImported = false;
    });
  }

  Future<void> _importAll() async {
    if (_rows.isEmpty) return;
    setState(() {
      _isLoading = true;
      _results = [];
      _hasImported = false;
    });

    final client = ApiClient();
    final results = <_ImportResult>[];

    for (final row in _rows) {
      if (row.email.isEmpty || row.nombreCompleto.isEmpty) {
        results.add(
          _ImportResult(
            name: row.nombreCompleto,
            email: row.email,
            success: false,
            message: 'Falta nombre o email',
          ),
        );
        continue;
      }

      // Username generado a partir del email (parte antes del @)
      final username = row.email.contains('@')
          ? row.email.split('@').first
          : row.rut.replaceAll('-', '').replaceAll('.', '');

      // Contraseña por defecto: RUT sin puntos y sin guión + "Kairos!"
      final defaultPassword =
          '${row.rut.replaceAll('.', '').replaceAll('-', '')}Kairos!';

      try {
        // Va por el endpoint del panel, no por el registro público: ese ya no
        // concede el rol staff, y además dejaría las cuentas en estado
        // pendiente, obligando al liceo a aprobar una por una las que acaba de
        // crear él mismo.
        await client.createAccountAsStaff(
          username: username,
          email: row.email,
          password: defaultPassword,
          fullName: row.nombreCompleto,
          institution: row.curso.isNotEmpty ? row.curso : null,
          role: _csvRole,
        );
        results.add(
          _ImportResult(
            name: row.nombreCompleto,
            email: row.email,
            success: true,
            message: 'Cuenta creada y aprobada — contraseña: $defaultPassword',
          ),
        );
      } catch (e) {
        results.add(
          _ImportResult(
            name: row.nombreCompleto,
            email: row.email,
            success: false,
            message: e.toString().contains('registrado')
                ? 'El correo ya está registrado'
                : 'Error al crear cuenta',
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
      _results = results;
      _hasImported = true;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: KairosPalette.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión de Usuarios',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: KairosPalette.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            KCard(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: KairosPalette.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.upload_file_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Importar usuarios desde CSV',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Carga masiva de estudiantes o staff desde un archivo CSV.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Formato esperado
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Formato del CSV',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'El archivo puede tener o no encabezados. Las columnas deben estar en este orden:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _expectedHeaders
                        .map(
                          (h) => Chip(
                            label: Text(
                              h,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: KairosPalette.muted,
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '12.345.678-9,Juan Pérez López,juan@liceo.cl,4°A,Mecatrónica,17\n'
                      '98.765.432-1,María Soto,maria@liceo.cl,3°B,Automatización,16',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selector de tipo de usuario
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tipo de usuario del CSV',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _roleChip('student', 'Estudiante', Icons.school_rounded),
                      _roleChip(
                        'staff',
                        'Staff / Docente',
                        Icons.manage_accounts_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Botón de carga
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Seleccionar archivo CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KairosPalette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // Vista previa de filas
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Vista previa — ${_rows.length} registros',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (!_hasImported)
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _importAll,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_rounded),
                      label: Text(
                        _isLoading ? 'Importando...' : 'Importar todos',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KairosPalette.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              KCard(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      KairosPalette.muted,
                    ),
                    columns: const [
                      DataColumn(label: Text('RUT')),
                      DataColumn(label: Text('Nombre')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Curso')),
                      DataColumn(label: Text('Especialidad')),
                      DataColumn(label: Text('Edad')),
                    ],
                    rows: _rows.map((r) {
                      final result = _hasImported
                          ? _results.firstWhere(
                              (res) => res.email == r.email,
                              orElse: () => _ImportResult(
                                name: r.nombreCompleto,
                                email: r.email,
                                success: false,
                                message: '',
                              ),
                            )
                          : null;
                      return DataRow(
                        color: result == null
                            ? null
                            : WidgetStateProperty.all(
                                result.success
                                    ? KairosPalette.success.withValues(
                                        alpha: 0.12,
                                      )
                                    : KairosPalette.danger.withValues(
                                        alpha: 0.12,
                                      ),
                              ),
                        cells: [
                          DataCell(Text(r.rut)),
                          DataCell(
                            Row(
                              children: [
                                Text(r.nombreCompleto),
                                if (result != null) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    result.success
                                        ? Icons.check_circle_rounded
                                        : Icons.error_rounded,
                                    size: 16,
                                    color: result.success
                                        ? KairosPalette.success
                                        : KairosPalette.danger,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          DataCell(Text(r.email)),
                          DataCell(Text(r.curso)),
                          DataCell(Text(r.especialidad)),
                          DataCell(Text(r.edad)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            // Resultados de importación
            if (_hasImported) ...[
              const SizedBox(height: 16),
              const Text(
                'Resultados',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              ..._results.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: KCard(
                    child: Row(
                      children: [
                        Icon(
                          r.success
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          color: r.success
                              ? KairosPalette.success
                              : KairosPalette.danger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                r.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: r.success
                                      ? KairosPalette.success
                                      : KairosPalette.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roleChip(String value, String label, IconData icon) {
    final selected = _csvRole == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _csvRole = value),
      selectedColor: KairosPalette.primary.withValues(alpha: 0.14),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected ? KairosPalette.primary : KairosPalette.foreground,
      ),
      side: BorderSide(
        color: selected ? KairosPalette.primary : KairosPalette.border,
        width: selected ? 2 : 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

class _CsvRow {
  const _CsvRow({
    required this.rut,
    required this.nombreCompleto,
    required this.email,
    required this.curso,
    required this.especialidad,
    required this.edad,
  });
  final String rut;
  final String nombreCompleto;
  final String email;
  final String curso;
  final String especialidad;
  final String edad;
}

class _ImportResult {
  const _ImportResult({
    required this.name,
    required this.email,
    required this.success,
    required this.message,
  });
  final String name;
  final String email;
  final bool success;
  final String message;
}
