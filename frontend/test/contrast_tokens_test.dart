import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/kairos_palette.dart';

double _contrast(Color foreground, Color background) {
  final lighter = foreground.computeLuminance();
  final darker = background.computeLuminance();
  final max = lighter > darker ? lighter : darker;
  final min = lighter > darker ? darker : lighter;
  return (max + 0.05) / (min + 0.05);
}

void main() {
  test('AA text tokens meet 4.5:1 against the light surface', () {
    for (final token in <String, Color>{
      'primary': KairosPalette.primary,
      'accent': KairosPalette.accent,
      'secondary': KairosPalette.secondary,
      'tertiary': KairosPalette.textTertiary,
      'success': KairosPalette.success,
      'warning': KairosPalette.warning,
      'danger': KairosPalette.danger,
    }.entries) {
      expect(
        _contrast(token.value, KairosPalette.card),
        greaterThanOrEqualTo(4.5),
        reason: '${token.key} must be readable on the card surface',
      );
    }
  });

  test('UI boundary and focus tokens meet 3:1 against the card', () {
    expect(
      _contrast(KairosPalette.border, KairosPalette.card),
      greaterThanOrEqualTo(3),
    );
    expect(
      _contrast(KairosPalette.focus, KairosPalette.card),
      greaterThanOrEqualTo(3),
    );
  });

  test('filled semantic actions support white text', () {
    for (final token in <String, Color>{
      'primary': KairosPalette.primary,
      'accent': KairosPalette.accent,
      'success': KairosPalette.success,
      'warning': KairosPalette.warning,
      'danger': KairosPalette.danger,
    }.entries) {
      expect(
        _contrast(Colors.white, token.value),
        greaterThanOrEqualTo(4.5),
        reason: 'white text on ${token.key} must remain readable',
      );
    }
  });
}
