import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/compartido/widgets/marco_visor.dart';

// Girar el visor: horizontal y pantalla completa, como en los videos.

void main() {
  late List<MethodCall> llamadas;

  setUp(() {
    llamadas = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
          llamadas.add(llamada);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<String>? ultimaOrientacion() {
    final llamada = llamadas.lastWhere(
      (l) => l.method == 'SystemChrome.setPreferredOrientations',
      orElse: () => const MethodCall(''),
    );
    return (llamada.arguments as List?)?.cast<String>();
  }

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MarcoVisor(
                  titulo: 'Guía',
                  claveVolver: Key('volver'),
                  cuerpo: ColoredBox(color: Colors.teal),
                ),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('el botón gira a horizontal en pantalla completa', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.byKey(const Key('girarVisor')), findsOneWidget);

    await tester.tap(find.byKey(const Key('girarVisor')));
    await tester.pump();

    expect(ultimaOrientacion(), [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    // Sin barra superior: el documento ocupa toda la pantalla.
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('salirGiroVisor')), findsOneWidget);
  });

  testWidgets('el botón flotante vuelve a vertical con la barra', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.byKey(const Key('girarVisor')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('salirGiroVisor')));
    await tester.pump();

    expect(ultimaOrientacion(), [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.portraitDown',
    ]);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('atrás primero vuelve a vertical y después cierra', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.byKey(const Key('girarVisor')));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MarcoVisor), findsOneWidget);
    expect(ultimaOrientacion()!.first, 'DeviceOrientation.portraitUp');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MarcoVisor), findsNothing);
  });

  testWidgets('cerrar el visor girado deja la app en vertical', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const Key('girarVisor')));
    await tester.pump();

    Navigator.of(tester.element(find.byType(MarcoVisor))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(MarcoVisor), findsNothing);
    expect(ultimaOrientacion()!.first, 'DeviceOrientation.portraitUp');
  });
}
