import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/app/tema/repintar.dart';
import 'package:oncuidar/app/tema/tema.dart';

/// Pinta un cuadro con el color de tarjeta vigente.
class _Muestra extends StatelessWidget {
  const _Muestra();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(key: const Key('muestra'), color: Paleta.tarjeta);
}

Color _colorMuestra(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byKey(const Key('muestra'))).color;

void main() {
  tearDown(() => Paleta.usar(coloresClaros));

  test('usar cambia la paleta y avisa solo si hubo cambio', () {
    expect(Paleta.esOscura, isFalse);
    expect(Paleta.usar(coloresOscuros), isTrue);
    expect(Paleta.esOscura, isTrue);
    expect(Paleta.tarjeta, coloresOscuros.tarjeta);
    expect(Paleta.usar(coloresOscuros), isFalse);
  });

  test('el relleno dorado bajo texto blanco no cambia con el modo', () {
    final claro = Paleta.doradoRelleno;
    Paleta.usar(coloresOscuros);
    expect(Paleta.doradoRelleno, claro);
  });

  // Con binding de widgets: Tema usa Google Fonts.
  testWidgets('el tema sigue el brillo de la paleta', (tester) async {
    expect(Tema.obtener().brightness, Brightness.light);
    Paleta.usar(coloresOscuros);
    final tema = Tema.obtener();
    expect(tema.brightness, Brightness.dark);
    expect(tema.scaffoldBackgroundColor, coloresOscuros.crema);
  });

  testWidgets('repintarArbol actualiza incluso los widgets const', (
    tester,
  ) async {
    late BuildContext raiz;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          raiz = context;
          return const Directionality(
            textDirection: TextDirection.ltr,
            child: _Muestra(),
          );
        },
      ),
    );
    expect(_colorMuestra(tester), coloresClaros.tarjeta);

    Paleta.usar(coloresOscuros);
    await tester.pump();
    // Sin repintar, el widget const conserva el color anterior.
    expect(_colorMuestra(tester), coloresClaros.tarjeta);

    repintarArbol(raiz);
    await tester.pump();
    expect(_colorMuestra(tester), coloresOscuros.tarjeta);
  });
}
