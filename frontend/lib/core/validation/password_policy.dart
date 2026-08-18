/// Política de contraseñas del cliente.
///
/// Es el espejo exacto de `AccountRules.ApplyPasswordPolicy` en el backend
/// (`Kairos.Application/Common/Validation/AccountRules.cs`). Si allá se
/// endurece una regla, hay que endurecerla acá: cuando el formulario acepta
/// algo que el servidor rechaza, la persona escribe una contraseña válida a
/// ojos de la interfaz y recibe un error 400 sin explicación útil.
///
/// Vive en `core/` y no dentro de la pantalla de registro porque la usan tanto
/// el registro público como el cambio de contraseña.
library;

class PasswordPolicy {
  const PasswordPolicy._();

  static const int minLength = 8;

  /// Texto que se muestra bajo el campo *antes* de escribir. Enunciar la regla
  /// por adelantado evita el ensayo y error (WCAG 3.3.2, etiquetas o
  /// instrucciones).
  static const String requirements =
      'Mínimo $minLength caracteres, con mayúscula, minúscula y un símbolo.';

  static final RegExp _upper = RegExp('[A-ZÁÉÍÓÚÑ]');
  static final RegExp _lower = RegExp('[a-záéíóúñ]');
  static final RegExp _symbol = RegExp(r'[^\w\s]');

  /// Devuelve `null` si la contraseña cumple, o el motivo del rechazo.
  ///
  /// Se informa una regla a la vez y en el mismo orden que el backend, para que
  /// el mensaje del formulario y el del servidor nunca se contradigan.
  static String? validate(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa una contraseña';
    if (value.length < minLength) {
      return 'La contraseña debe tener al menos $minLength caracteres.';
    }
    if (!_upper.hasMatch(value)) {
      return 'La contraseña debe incluir al menos una mayúscula.';
    }
    if (!_lower.hasMatch(value)) {
      return 'La contraseña debe incluir al menos una minúscula.';
    }
    if (!_symbol.hasMatch(value)) {
      return 'La contraseña debe incluir al menos un carácter especial.';
    }
    return null;
  }
}
