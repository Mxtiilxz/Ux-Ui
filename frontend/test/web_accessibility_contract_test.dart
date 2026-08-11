import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web document declares Spanish and preserves browser zoom', () async {
    final index = await File('web/index.html').readAsString();

    expect(index, contains('<html lang="es">'));
    expect(index, contains('user-scalable=yes'));
    expect(index, contains('maximum-scale=5.0'));
    expect(index, isNot(contains('user-scalable=no')));
    expect(index, contains('preserveAccessibleViewport'));
  });
}
