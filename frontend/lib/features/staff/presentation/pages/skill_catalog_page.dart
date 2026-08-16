import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/kairos_palette.dart';
import '../../../../core/widgets/k_card.dart';

/// Gestión del catálogo de competencias de Quick Match.
///
/// El catálogo es el vocabulario común entre alumnos y empresas: un alumno solo
/// puede declarar competencias de esta lista, y una empresa solo puede buscar
/// por ellas. Si no refleja las especialidades del liceo, Quick Match empareja
/// mal o directamente no empareja.
class SkillCatalogPage extends StatefulWidget {
  const SkillCatalogPage({super.key});

  @override
  State<SkillCatalogPage> createState() => _SkillCatalogPageState();
}

/// Las categorías vienen del enum `SkillCategory` del backend; el valor viaja
/// en inglés y solo la etiqueta se traduce.
const Map<String, String> _categoryLabels = {
  'Technical': 'Técnica',
  'Language': 'Idioma',
  'Experience': 'Experiencia',
};

class _SkillCatalogPageState extends State<SkillCatalogPage> {
  final _api = ApiClient();
  final _nameController = TextEditingController();

  List<Map<String, dynamic>> _catalog = [];
  bool _loading = true;
  bool _creating = false;
  String _newCategory = 'Technical';
  final Set<int> _deleting = {};
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getSkillCatalog();
      if (mounted) setState(() => _catalog = data);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _statusMessage = 'No se pudo cargar el catálogo de competencias.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// El backend explica en el cuerpo por qué rechazó la operación —nombre
  /// repetido, competencia en uso—. Ese texto es más útil que un genérico.
  String _reasonFrom(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
    }
    return fallback;
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _creating = true);
    try {
      await _api.createSkill(name: name, category: _newCategory);
      _nameController.clear();
      await _load();
      if (mounted) {
        setState(() => _statusMessage = 'Competencia "$name" agregada.');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _statusMessage = _reasonFrom(
            error,
            'No se pudo agregar la competencia.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _delete(int id, String name) async {
    setState(() => _deleting.add(id));
    try {
      await _api.deleteSkill(id);
      await _load();
      if (mounted) {
        setState(() => _statusMessage = 'Competencia "$name" eliminada.');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _statusMessage = _reasonFrom(
            error,
            'No se pudo eliminar la competencia.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Competencias de Quick Match',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const KCard(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Los alumnos eligen sus competencias de esta lista y las empresas '
                  'buscan candidatos por ellas. Mantenerla al día con las '
                  'especialidades del liceo es lo que hace útil a Quick Match.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _addForm(),
            const SizedBox(height: 16),
            if (_statusMessage != null) ...[
              Semantics(
                liveRegion: true,
                container: true,
                label: _statusMessage!,
                child: KCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_statusMessage!)),
                        IconButton(
                          tooltip: 'Descartar el mensaje',
                          onPressed: () =>
                              setState(() => _statusMessage = null),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_loading)
              Semantics(
                liveRegion: true,
                container: true,
                label: 'Cargando el catálogo de competencias',
                child: const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_catalog.isEmpty)
              const KCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'El catálogo está vacío. Mientras lo esté, los alumnos no '
                    'pueden declarar competencias y Quick Match no devuelve '
                    'candidatos.',
                  ),
                ),
              )
            else
              ..._categoryLabels.entries.map(_categorySection),
          ],
        ),
      ),
    );
  }

  Widget _addForm() {
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agregar una competencia',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            // Wrap y no Row: al 200 % de escala de texto, una fila fija dejaría
            // el botón fuera de pantalla.
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _nameController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la competencia',
                      hintText: 'Ej: Instalaciones sanitarias',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _creating ? null : _create(),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: _newCategory,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: _categoryLabels.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _newCategory = value);
                    },
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _creating ? null : _create,
                  icon: _creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded, size: 18),
                  label: Text(_creating ? 'Agregando…' : 'Agregar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _categorySection(MapEntry<String, String> category) {
    final items = _catalog
        .where((skill) => skill['category'] == category.key)
        .toList(growable: false);

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${category.value} · ${items.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...items.map(_skillRow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skillRow(Map<String, dynamic> skill) {
    final id = skill['id'] as int;
    final name = skill['name'] as String? ?? '';
    final userCount = skill['userCount'] as int? ?? 0;
    final inUse = userCount > 0;
    final deleting = _deleting.contains(id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name),
                Text(
                  userCount == 0
                      ? 'Ningún alumno la tiene'
                      : userCount == 1
                      ? '1 alumno la tiene'
                      : '$userCount alumnos la tienen',
                  style: const TextStyle(
                    fontSize: 12,
                    color: KairosPalette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          // Una competencia en uso no se puede borrar: hacerlo la quitaría del
          // perfil de cada alumno que la declaró. El motivo va en el tooltip
          // para que el botón deshabilitado no sea un misterio.
          IconButton(
            tooltip: inUse
                ? 'No se puede eliminar "$name": está en el perfil de $userCount '
                      '${userCount == 1 ? "alumno" : "alumnos"}'
                : 'Eliminar "$name" del catálogo',
            onPressed: inUse || deleting ? null : () => _delete(id, name),
            icon: deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.delete_outline_rounded,
                    color: inUse ? null : KairosPalette.danger,
                  ),
          ),
        ],
      ),
    );
  }
}
