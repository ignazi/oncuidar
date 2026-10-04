import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/caracteristicas/chat/dominio/conversacion.dart';
import 'package:oncuidar/caracteristicas/chat/presentacion/widgets/burbujas_chat.dart';

Widget _envolver(Widget hijo) => MaterialApp(home: Scaffold(body: hijo));

void main() {
  testWidgets('la burbuja muestra la hora de envío', (tester) async {
    await tester.pumpWidget(
      _envolver(
        BurbujaMensaje(
          mensaje: MensajeConversacion(
            texto: 'Hola',
            delUsuario: true,
            enviadoEn: DateTime(2026, 10, 4, 21, 5),
          ),
        ),
      ),
    );

    expect(find.text('9:05 PM'), findsOneWidget);
  });

  testWidgets('sin hora de envío no muestra marca de hora', (tester) async {
    await tester.pumpWidget(
      _envolver(
        const BurbujaMensaje(
          mensaje: MensajeConversacion(texto: 'Antiguo', delUsuario: false),
        ),
      ),
    );

    expect(find.byKey(const Key('horaMensajeChat')), findsNothing);
  });

  testWidgets('el separador nombra el día', (tester) async {
    await tester.pumpWidget(
      _envolver(
        SeparadorDia(
          fecha: DateTime(2026, 10, 3, 9),
          ahora: DateTime(2026, 10, 4, 9),
        ),
      ),
    );

    expect(find.text('Ayer'), findsOneWidget);
  });
}
