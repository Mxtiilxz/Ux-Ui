import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/validation/password_policy.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.onRegisterSuccess,
    this.onPendingApproval,
  });

  final void Function(UserProfile user, String token) onRegisterSuccess;

  /// Se invoca cuando la cuenta creada queda a la espera de aprobación, para
  /// que la aplicación muestre la pantalla de espera en vez de un error.
  final void Function(String email, String password)? onPendingApproval;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  // Nombres y apellidos separados: el nombre de usuario lo deriva el servidor
  // del primer nombre y el primer apellido, así el liceo controla cómo
  // aparecen sus alumnos en vez de dejarlo a elección de cada uno.
  final _firstNamesController = TextEditingController();
  final _lastNamesController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _institutionController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String _selectedRole = 'student';
  final _roleFocusNodes = <String, FocusNode>{
    'student': FocusNode(debugLabel: 'Register student role'),
    'company': FocusNode(debugLabel: 'Register company role'),
  };

  /// Roles que se pueden pedir desde el registro público.
  ///
  /// "Staff del Liceo" estaba aquí y se quitó: es el rol que aprueba cuentas y
  /// administra a los demás usuarios, así que ofrecerlo en un formulario abierto
  /// convertía la aprobación en el único obstáculo entre un alumno y los
  /// permisos de administración. Esas cuentas las crea el liceo desde el panel.
  static const _roles = [
    _RoleOption(
      'student',
      'Estudiante',
      Icons.school_rounded,
      'Postula a prácticas y oportunidades laborales',
    ),
    _RoleOption(
      'company',
      'Empresa',
      Icons.business_rounded,
      'Publica ofertas y conecta con talento técnico',
    ),
  ];

  @override
  void dispose() {
    _firstNamesController.dispose();
    _lastNamesController.dispose();
    _companyNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _institutionController.dispose();
    for (final node in _roleFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _institutionLabel() => 'Liceo (opcional)';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final isCompany = _selectedRole == 'company';
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final client = ApiClient();
      final registration = await client.register(
        email: email,
        password: password,
        role: _selectedRole,
        firstNames: isCompany ? null : _firstNamesController.text.trim(),
        lastNames: isCompany ? null : _lastNamesController.text.trim(),
        companyName: isCompany ? _companyNameController.text.trim() : null,
        institution: _institutionController.text.trim().isEmpty
            ? null
            : _institutionController.text.trim(),
      );

      // Un alumno queda pendiente de aprobación, así que no tiene sentido
      // intentar iniciar sesión: el servidor lo rechazaría. Se le muestra la
      // pantalla de espera, que entra sola cuando el liceo lo aprueba.
      if (registration['status'] == 'pending') {
        if (!mounted) return;
        setState(() => _isLoading = false);
        widget.onPendingApproval?.call(email, password);
        return;
      }

      // Una empresa entra directo.
      final loginResponse = await client.login(email, password);

      final token = loginResponse['token'] as String;
      final userId = (loginResponse['userId'] as int? ?? 0).toString();
      final fullName =
          loginResponse['fullName'] as String? ??
          registration['fullName'] as String? ??
          '';
      final avatarUrl = loginResponse['profilePictureUrl'] as String? ?? '';
      final roleStr = loginResponse['role'] as String? ?? _selectedRole;

      await client.saveToken(token);
      await client.saveProfile({
        'id': userId,
        'fullName': fullName,
        'role': roleStr,
        'title': _titleForRole(_selectedRole),
        'profilePictureUrl': avatarUrl,
      });

      final user = UserProfile(
        id: userId,
        name: fullName,
        role: _mapRole(roleStr),
        title: _titleForRole(_selectedRole),
        avatarUrl: avatarUrl,
        skills: const [],
        bio: '',
        location: '',
        connections: 0,
      );

      if (!mounted) return;
      widget.onRegisterSuccess(user, token);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final data = e.response?.data;
      final message = data is Map
          ? (data['detail'] ??
                data['message'] ??
                data['title'] ??
                'Error al registrar')
          : 'Error al registrar (${e.response?.statusCode})';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  UserRole _mapRole(String role) => switch (role) {
    'staff' => UserRole.staff,
    'company' => UserRole.company,
    'alumni' => UserRole.alumni,
    _ => UserRole.student,
  };

  String _titleForRole(String role) => switch (role) {
    'staff' => 'Staff del Liceo',
    'company' => 'Representante de Empresa',
    _ => 'Estudiante',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hub_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Kairos',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Crear cuenta',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Selector de rol
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tipo de cuenta',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RadioGroup<String>(
                        groupValue: _selectedRole,
                        onChanged: (role) {
                          if (role != null) {
                            setState(() => _selectedRole = role);
                          }
                        },
                        child: Column(
                          children: _roles
                              .map(
                                (r) => _RoleTile(
                                  option: r,
                                  selected: _selectedRole == r.value,
                                  focusNode: _roleFocusNodes[r.value]!,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Formulario
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // El formulario cambia con el rol: una empresa no tiene
                        // nombres ni apellidos, y un alumno no tiene razón
                        // social. El campo de nombre de usuario desapareció:
                        // ahora lo deriva el servidor del nombre real.
                        if (_selectedRole == 'company')
                          _field(
                            controller: _companyNameController,
                            label: 'Nombre de la empresa',
                            hint: 'TechSolutions Chile SpA',
                            icon: Icons.business_outlined,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Ingresa el nombre de la empresa'
                                : null,
                          )
                        else ...[
                          _field(
                            controller: _firstNamesController,
                            label: 'Nombres',
                            hint: 'Ana María',
                            icon: Icons.person_outline,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Ingresa tus nombres'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _field(
                            controller: _lastNamesController,
                            label: 'Apellidos',
                            hint: 'Pérez Soto',
                            icon: Icons.badge_outlined,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Ingresa tus apellidos'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _field(
                          controller: _emailController,
                          label: 'Correo electrónico',
                          hint: _selectedRole == 'company'
                              ? 'contacto@tuempresa.cl'
                              : 'nombre@kairos.cl',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Ingresa tu correo';
                            if (!value.contains('@')) return 'Correo inválido';
                            // El liceo exige su dominio para los alumnos; se
                            // avisa aquí en vez de esperar el rechazo del
                            // servidor tras rellenar todo el formulario.
                            if (_selectedRole != 'company' &&
                                !value.toLowerCase().endsWith('@kairos.cl')) {
                              return 'Debe ser tu correo @kairos.cl del liceo';
                            }
                            return null;
                          },
                        ),
                        // La empresa ya dio su razón social arriba; pedirle
                        // además una "institución" duplicaba el mismo dato con
                        // dos etiquetas iguales.
                        if (_selectedRole != 'company') ...[
                          const SizedBox(height: 14),
                          _field(
                            controller: _institutionController,
                            label: _institutionLabel(),
                            hint: 'Liceo Técnico Cardenal José María Caro',
                            icon: Icons.business_outlined,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _field(
                          controller: _passwordController,
                          label: 'Contraseña',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          // Las reglas se enuncian antes de escribir, no como
                          // castigo al enviar (WCAG 3.3.2). Van como
                          // `helperText` y no como un texto suelto debajo
                          // porque así quedan asociadas al campo en el árbol de
                          // semántica y el lector de pantalla las lee al
                          // enfocarlo.
                          helperText: PasswordPolicy.requirements,
                          validator: PasswordPolicy.validate,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _confirmController,
                          label: 'Confirmar contraseña',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          obscureText: _obscureConfirm,
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirm
                                ? 'Mostrar confirmación de contraseña'
                                : 'Ocultar confirmación de contraseña',
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Crear cuenta',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      '¿Ya tienes cuenta? ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: const Text(
                        'Inicia sesión',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            labelText: label,
            helperText: helperText,
            helperMaxLines: 3,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, size: 18, color: AppColors.textTertiary),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleOption {
  const _RoleOption(this.value, this.label, this.icon, this.description);
  final String value;
  final String label;
  final IconData icon;
  final String description;
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.option,
    required this.selected,
    required this.focusNode,
  });
  final _RoleOption option;
  final bool selected;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: RadioListTile<String>(
          value: option.value,
          selected: selected,
          focusNode: focusNode,
          activeColor: AppColors.primary,
          controlAffinity: ListTileControlAffinity.trailing,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          secondary: ExcludeSemantics(
            child: Icon(
              option.icon,
              color: selected ? AppColors.primary : AppColors.textTertiary,
              size: 22,
            ),
          ),
          title: Text(
            option.label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: selected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            option.description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
