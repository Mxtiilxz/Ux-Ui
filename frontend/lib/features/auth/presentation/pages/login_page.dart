import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/analytics/analytics.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_colors.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLoginSuccess});

  final void Function(UserProfile user) onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _demoRoleFocusNodes = <String, FocusNode>{
    'student': FocusNode(debugLabel: 'Demo student role'),
    'company': FocusNode(debugLabel: 'Demo company role'),
  };
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    for (final node in _demoRoleFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Perfil elegido por el tester en modo demo. Solo estudiante o empresa:
  /// el rol staff (administración del liceo) no se ofrece a propósito.
  String _demoRole = 'student';

  Future<void> _submitDemo() async {
    setState(() => _isLoading = true);

    final client = ApiClient();
    final name = _demoRole == 'company'
        ? 'Automatización Industrial S.A.'
        : 'Camila Vidal Astorga';

    final response = await client.demoLogin(role: _demoRole, name: name);
    Analytics.login(_demoRole);

    final roleStr = response['role'] as String? ?? 'student';
    await client.saveToken(response['token'] as String);
    await client.saveProfile({
      'id': (response['userId'] as int? ?? 0).toString(),
      'fullName': name,
      'role': roleStr,
      'title': _titleForRole(roleStr),
      'institution': response['institution'] as String?,
      'quickMatchVisible': (response['quickMatchVisible'] as bool? ?? false)
          .toString(),
    });

    if (!mounted) return;
    widget.onLoginSuccess(
      UserProfile(
        id: (response['userId'] as int? ?? 0).toString(),
        name: name,
        role: _mapRole(roleStr),
        title: _titleForRole(roleStr),
        avatarUrl: '',
        skills: const [],
        bio: '',
        location: '',
        connections: 0,
        institution: response['institution'] as String?,
        quickMatchVisible: response['quickMatchVisible'] as bool? ?? false,
      ),
    );
  }

  Future<void> _submit() async {
    if (kDemoMode) return _submitDemo();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final client = ApiClient();
      final response = await client.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final token = response['token'] as String;
      final userId = (response['userId'] as int? ?? 0).toString();
      final fullName = response['fullName'] as String? ?? 'Usuario';
      final avatarUrl = response['profilePictureUrl'] as String? ?? '';
      final institution = response['institution'] as String?;
      final quickMatchVisible = response['quickMatchVisible'] as bool? ?? false;

      await client.saveToken(token);

      final roleStr = response['role'] as String? ?? 'student';
      final titleStr = _titleForRole(roleStr);
      await client.saveProfile({
        'id': userId,
        'fullName': fullName,
        'role': roleStr,
        'title': titleStr,
        'profilePictureUrl': avatarUrl,
        'institution': institution,
        'quickMatchVisible': quickMatchVisible.toString(),
      });

      final user = UserProfile(
        id: userId,
        name: fullName,
        role: _mapRole(roleStr),
        title: titleStr,
        avatarUrl: avatarUrl,
        skills: const [],
        bio: '',
        location: '',
        connections: 0,
        institution: institution,
        quickMatchVisible: quickMatchVisible,
      );

      if (!mounted) return;
      widget.onLoginSuccess(user);
    } on DioException catch (e) {
      if (!mounted) return;

      if (_isBackendUnavailable(e)) {
        final demoUser = _buildDemoUser();
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backend no disponible. Ingresando en modo demo.'),
            backgroundColor: AppColors.warning,
          ),
        );
        widget.onLoginSuccess(demoUser);
        return;
      }

      setState(() => _isLoading = false);
      final message = _extractErrorMessage(e.response?.data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.danger),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al conectar con el servidor'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  bool _isBackendUnavailable(DioException e) {
    if (e.response != null) return false;
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.unknown;
  }

  String _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final raw = data['detail'] ?? data['message'] ?? data['title'];
      final text = raw?.toString().trim();
      if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    final text = data?.toString().trim();
    if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }

    return 'No se pudo iniciar sesion.';
  }

  UserProfile _buildDemoUser() {
    final emailOrUser = _emailController.text.trim();
    final role = _roleFromInput(emailOrUser);

    final displayName = emailOrUser.isEmpty
        ? 'Usuario Demo'
        : emailOrUser.split('@').first.replaceAll('.', ' ').trim();

    return UserProfile(
      id: 'demo-user',
      name: displayName.isEmpty ? 'Usuario Demo' : displayName,
      role: role,
      title: _titleForRole(role.name),
      avatarUrl: '',
      skills: const [],
      bio: 'Modo demo sin conexion al backend.',
      location: 'La Florida, Santiago',
      connections: 0,
      institution: role == UserRole.company
          ? null
          : 'Liceo Tecnico Cardenal Jose Maria Caro',
    );
  }

  UserRole _roleFromInput(String text) {
    final normalized = text.toLowerCase();
    // El rol staff (administración del liceo) queda deliberadamente fuera:
    // los testers no deben poder entrar al panel de gestión.
    if (normalized.contains('company') ||
        normalized.contains('empresa') ||
        normalized.contains('hr')) {
      return UserRole.company;
    }
    if (normalized.contains('alumni') || normalized.contains('egresado')) {
      return UserRole.alumni;
    }
    return UserRole.student;
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
    'alumni' => 'Egresado / Alumni',
    _ => 'Estudiante',
  };

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterPage(
          onRegisterSuccess: (user, _) => widget.onLoginSuccess(user),
        ),
      ),
    );
  }

  /// Selector de perfil del modo demo. Reemplaza a los campos de credenciales:
  /// el tester elige cómo quiere recorrer la app y entra de inmediato.
  Widget _buildDemoRoleSelector() {
    return RadioGroup<String>(
      groupValue: _demoRole,
      onChanged: (role) {
        if (!_isLoading && role != null) {
          setState(() => _demoRole = role);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Elige con qué perfil quieres recorrer la plataforma.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _demoRoleOption(
            role: 'student',
            icon: Icons.school_rounded,
            title: 'Estudiante',
            subtitle: 'Explora el feed, tus competencias y postula a ofertas.',
          ),
          const SizedBox(height: 10),
          _demoRoleOption(
            role: 'company',
            icon: Icons.business_center_rounded,
            title: 'Empresa',
            subtitle: 'Publica ofertas y busca talento con Quick Match.',
          ),
        ],
      ),
    );
  }

  Widget _demoRoleOption({
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _demoRole == role;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: role,
        selected: selected,
        enabled: !_isLoading,
        focusNode: _demoRoleFocusNodes[role],
        activeColor: AppColors.primary,
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        secondary: ExcludeSemantics(child: Icon(icon)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.hub_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Kairos',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Conectando estudiantes con oportunidades',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  // Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (kDemoMode) ...[
                            _buildDemoRoleSelector(),
                          ] else ...[
                            // Email / Username
                            _FormField(
                              controller: _emailController,
                              label: 'Correo o usuario',
                              hint: 'correo@liceo.cl',
                              prefixIcon: Icons.person_outline,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Ingresa tu correo o usuario';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Password
                            _FormField(
                              controller: _passwordController,
                              label: 'Contraseña',
                              hint: '••••••••',
                              prefixIcon: Icons.lock_outline,
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
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Ingresa tu contraseña';
                                }
                                if (v.length < 6) {
                                  return 'Mínimo 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                child: const Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Submit
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
                                      'Ingresar',
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
                  if (kDemoMode)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Versión de demostración para pruebas de uso. Los cambios '
                        'que hagas se mantienen durante la sesión y se reinician '
                        'al recargar la página.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          '¿No tienes cuenta? ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        TextButton(
                          onPressed: _goToRegister,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: const Text(
                            'Regístrate',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
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
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              prefixIcon,
              size: 18,
              color: AppColors.textTertiary,
            ),
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
