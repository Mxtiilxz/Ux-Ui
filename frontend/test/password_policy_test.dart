import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/validation/password_policy.dart';

/// La regla del formulario tiene que ser la misma que la del servidor
/// (`AccountRules.ApplyPasswordPolicy`). Cuando divergen, el registro acepta
/// una contraseña que el backend rechaza y la persona recibe un 400 sin
/// explicación. Este test es el que impide que vuelvan a separarse.
void main() {
  group('acepta', () {
    test('una contraseña que cumple las cuatro reglas', () {
      expect(PasswordPolicy.validate('Practica2026!'), isNull);
    });

    test('símbolos distintos y acentos', () {
      expect(PasswordPolicy.validate('Ñandú#Volador'), isNull);
    });
  });

  group('rechaza', () {
    test('vacía', () {
      expect(PasswordPolicy.validate(''), 'Ingresa una contraseña');
      expect(PasswordPolicy.validate(null), 'Ingresa una contraseña');
    });

    test('de menos de 8 caracteres, aunque cumpla el resto', () {
      expect(PasswordPolicy.validate('Ab1!xy'), contains('8 caracteres'));
    });

    test('sin mayúscula', () {
      expect(PasswordPolicy.validate('practica2026!'), contains('mayúscula'));
    });

    test('sin minúscula', () {
      expect(PasswordPolicy.validate('PRACTICA2026!'), contains('minúscula'));
    });

    test('sin carácter especial', () {
      expect(PasswordPolicy.validate('Practica2026'), contains('especial'));
    });

    // El caso concreto que el formulario dejaba pasar antes: seis caracteres
    // bastaban en el cliente y el servidor devolvía un error.
    test('la contraseña de 6 caracteres que el cliente aceptaba', () {
      expect(PasswordPolicy.validate('abc123'), isNotNull);
    });
  });
}
