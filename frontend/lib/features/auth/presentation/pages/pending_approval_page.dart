import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/kairos_palette.dart';

/// Pantalla de espera de aprobación.
///
/// Un alumno que se registra queda en estado `pending` hasta que el liceo lo
/// aprueba. Antes eso se comunicaba como un error de acceso, indistinguible de
/// una contraseña equivocada: la persona no sabía si había hecho algo mal o si
/// solo tenía que esperar.
///
/// La pantalla reintenta el acceso sola cada pocos segundos, así que cuando el
/// personal aprueba la solicitud el alumno entra sin tener que hacer nada.
class PendingApprovalPage extends StatefulWidget {
  const PendingApprovalPage({
    super.key,
    required this.email,
    required this.password,
    required this.onApproved,
    required this.onCancel,
  });

  final String email;

  /// Se conserva en memoria solo mientras dura la espera, para poder reintentar
  /// el acceso sin volver a pedirla.
  final String password;

  /// Recibe la respuesta del login en cuanto la cuenta queda habilitada.
  final void Function(Map<String, dynamic> loginResponse) onApproved;

  final VoidCallback onCancel;

  @override
  State<PendingApprovalPage> createState() => _PendingApprovalPageState();
}

class _PendingApprovalPageState extends State<PendingApprovalPage> {
  static const _pollInterval = Duration(seconds: 8);

  Timer? _timer;
  bool _checking = false;
  bool _rejected = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_pollInterval, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || _rejected) return;
    setState(() => _checking = true);

    try {
      final response = await ApiClient().login(widget.email, widget.password);
      _timer?.cancel();
      if (!mounted) return;
      widget.onApproved(response);
    } catch (error) {
      // Seguir esperando es lo normal aquí. Solo el rechazo cambia el mensaje:
      // esa espera no va a terminar nunca.
      if (mounted && ApiClient.accountStatusOf(error) == 'rejected') {
        setState(() => _rejected = true);
        _timer?.cancel();
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KairosPalette.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Semantics(
              container: true,
              liveRegion: true,
              label: _rejected
                  ? 'Tu solicitud fue rechazada.'
                  : 'Tu cuenta está pendiente de aprobación del personal del liceo.',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Kairos',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: KairosPalette.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_rejected)
                    const Icon(
                      Icons.cancel_outlined,
                      size: 56,
                      color: KairosPalette.danger,
                    )
                  else
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(strokeWidth: 5),
                    ),
                  const SizedBox(height: 28),
                  Text(
                    _rejected
                        ? 'Tu solicitud fue rechazada'
                        : 'Tu cuenta está en espera',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: KairosPalette.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _rejected
                        ? 'Comunícate con el personal del liceo para saber el motivo.'
                        : 'Un integrante del personal del liceo debe aprobarla. '
                              'En cuanto lo haga entrarás automáticamente, sin '
                              'necesidad de volver a iniciar sesión.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: KairosPalette.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: KairosPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!_rejected)
                    TextButton.icon(
                      onPressed: _checking ? null : _check,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        _checking ? 'Comprobando…' : 'Comprobar ahora',
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  TextButton(
                    onPressed: widget.onCancel,
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text('Volver al inicio de sesión'),
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
