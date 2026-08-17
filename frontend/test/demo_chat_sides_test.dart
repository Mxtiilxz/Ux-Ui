import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/api/demo_backend.dart';

/// Reproduce el contacto de Quick Match en modo demo: la empresa escribe a un
/// candidato y después abre la conversación. El mensaje tiene que quedar
/// atribuido a la empresa, no al alumno.
void main() {
  test('el mensaje que envía la empresa queda a su nombre', () async {
    final demo = DemoBackend.instance..reset();

    // Sesión de empresa, como en el selector de perfil del modo demo.
    await demo.login('demo@kairos.cl', 'company', 'Automatización Industrial S.A.');

    const candidateId = 105; // Valentina, sin conversación previa.
    await demo.sendMessage(candidateId, 'Hola, vimos tu perfil.');

    final thread = await demo.getMessages(candidateId);

    expect(thread, hasLength(1));
    expect(
      thread.single['senderId'],
      201,
      reason: 'La empresa es el usuario 201 en la demo',
    );
  });

  test('la conversación sembrada conserva quién dijo qué', () async {
    final demo = DemoBackend.instance..reset();
    await demo.login('demo@kairos.cl', 'company', 'Automatización Industrial S.A.');

    final thread = await demo.getMessages(101);

    expect(thread.first['senderId'], 201, reason: 'lo escribió la empresa');
    expect(thread.last['senderId'], 101, reason: 'respondió la alumna');
  });
}
