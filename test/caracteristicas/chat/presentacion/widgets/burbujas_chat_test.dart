import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('la respuesta con material ofrece abrirlo', (tester) async {
    var abierto = false;
    await tester.pumpWidget(
      _envolver(
        BurbujaMensaje(
          mensaje: const MensajeConversacion(
            texto: 'Respuesta',
            delUsuario: false,
            materialId: 'm1',
          ),
          alAbrirMaterial: () => abierto = true,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('verMaterialChat')));

    expect(abierto, isTrue);
  });

  testWidgets('el mensaje del usuario nunca ofrece material', (tester) async {
    await tester.pumpWidget(
      _envolver(
        BurbujaMensaje(
          mensaje: const MensajeConversacion(texto: 'Hola', delUsuario: true),
          alAbrirMaterial: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('verMaterialChat')), findsNothing);
  });

  testWidgets('la sugerencia de consulta aparece solo si corresponde', (
    tester,
  ) async {
    await tester.pumpWidget(
      _envolver(
        const BurbujaMensaje(
          mensaje: MensajeConversacion(
            texto: 'Respuesta',
            delUsuario: false,
            sugerenciaConsulta: true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('sugerenciaConsultaChat')), findsOneWidget);

    await tester.pumpWidget(
      _envolver(
        const BurbujaMensaje(
          mensaje: MensajeConversacion(texto: 'Respuesta', delUsuario: false),
        ),
      ),
    );
    expect(find.byKey(const Key('sugerenciaConsultaChat')), findsNothing);
  });

  testWidgets('mantener pulsado copia el texto del mensaje', (tester) async {
    String? copiado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (llamada) async {
        if (llamada.method == 'Clipboard.setData') {
          copiado = (llamada.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      _envolver(
        const BurbujaMensaje(
          mensaje: MensajeConversacion(
            texto: 'Texto a copiar',
            delUsuario: false,
          ),
        ),
      ),
    );

    await tester.longPress(find.byKey(const Key('burbujaMensajeChat')));
    await tester.pump();

    expect(copiado, 'Texto a copiar');
    expect(find.text('Mensaje copiado'), findsOneWidget);
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

  group('hora al estilo WhatsApp', () {
    Future<void> montar(
      WidgetTester tester,
      MensajeConversacion mensaje,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_envolver(BurbujaMensaje(mensaje: mensaje)));
    }

    MensajeConversacion mensaje(String texto, {bool usuario = true}) =>
        MensajeConversacion(
          texto: texto,
          delUsuario: usuario,
          enviadoEn: DateTime(2026, 10, 4, 21, 5),
        );

    testWidgets('en un mensaje corto la hora comparte la línea del texto', (
      tester,
    ) async {
      await montar(tester, mensaje('Hola'));

      final hora = tester.getRect(find.byKey(const Key('horaMensajeChat')));
      final texto = tester.getRect(find.text('Hola'));
      // Mismo renglón: la hora queda dentro de la altura del texto, a su derecha.
      expect(hora.center.dy, closeTo(texto.center.dy, texto.height));
      expect(hora.left, greaterThan(texto.right));
      // La burbuja es compacta: una sola línea más el relleno.
      final burbuja = tester.getSize(
        find.byKey(const Key('burbujaMensajeChat')),
      );
      expect(burbuja.height, lessThan(45));
    });

    testWidgets(
      'si la última línea no deja sitio, la hora va debajo a la derecha',
      (tester) async {
        // Una sola palabra casi del ancho máximo: la hora ya no cabe a su lado.
        final largo = 'a' * 34;
        await montar(tester, mensaje(largo));

        final hora = tester.getRect(find.byKey(const Key('horaMensajeChat')));
        final texto = tester.getRect(find.text(largo));
        expect(hora.top, greaterThanOrEqualTo(texto.bottom - 1));
        // Pegada al borde derecho de la burbuja.
        final burbuja = tester.getRect(
          find.byKey(const Key('burbujaMensajeChat')),
        );
        expect(hora.right, lessThanOrEqualTo(burbuja.right));
        expect(burbuja.right - hora.right, lessThan(20));
      },
    );

    testWidgets(
      'la hora queda abajo a la derecha de un texto de varias líneas',
      (tester) async {
        await montar(tester, mensaje('palabra ' * 20, usuario: false));

        final hora = tester.getRect(find.byKey(const Key('horaMensajeChat')));
        final burbuja = tester.getRect(
          find.byKey(const Key('burbujaMensajeChat')),
        );
        expect(hora.bottom, greaterThan(burbuja.center.dy));
        expect(burbuja.right - hora.right, lessThan(20));
      },
    );

    testWidgets('con texto muy grande tampoco desborda', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, hijo) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: hijo!,
          ),
          home: Scaffold(
            body: BurbujaMensaje(mensaje: mensaje('palabra ' * 12)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('letra del usuario', () {
    testWidgets('es más gruesa que la del asistente', (tester) async {
      FontWeight? peso(WidgetTester t, String texto) =>
          t.widget<Text>(find.text(texto)).style?.fontWeight;

      await tester.pumpWidget(
        _envolver(
          const Column(
            children: [
              BurbujaMensaje(
                mensaje: MensajeConversacion(texto: 'mío', delUsuario: true),
              ),
              BurbujaMensaje(
                mensaje: MensajeConversacion(texto: 'bot', delUsuario: false),
              ),
            ],
          ),
        ),
      );

      expect(peso(tester, 'mío'), FontWeight.w700);
      expect(peso(tester, 'bot'), FontWeight.w400);
    });
  });
}
