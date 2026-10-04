import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/app/tema/repintar.dart';
import 'package:oncuidar/app/tema/tema.dart';
import 'package:oncuidar/compartido/widgets/fondo_hoja.dart';

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

  test('en oscuro, los rellenos bajo texto blanco son más profundos', () {
    final claro = Paleta.doradoRelleno;
    final bannerClaro = Paleta.degradadoBanner;
    Paleta.usar(coloresOscuros);
    expect(
      Paleta.doradoRelleno.computeLuminance(),
      lessThan(claro.computeLuminance()),
    );
    for (final (i, color) in Paleta.degradadoBanner.indexed) {
      expect(
        color.computeLuminance(),
        lessThan(bannerClaro[i].computeLuminance()),
      );
    }
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

  testWidgets('una hoja inferior abierta cambia de color al cambiar de modo', (
    tester,
  ) async {
    // Como en la app: se repinta desde arriba del MaterialApp, que contiene
    // el Navigator y, con él, las hojas abiertas.
    late BuildContext raiz;
    await tester.pumpWidget(
      Builder(
        builder: (arriba) {
          raiz = arriba;
          return MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const FondoHoja(
                        child: SizedBox(key: Key('contenidoHoja'), height: 100),
                      ),
                    ),
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    Color fondo() => tester
        .widget<Material>(
          find
              .ancestor(
                of: find.byKey(const Key('contenidoHoja')),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;

    expect(fondo(), coloresClaros.crema);

    Paleta.usar(coloresOscuros);
    repintarArbol(raiz);
    await tester.pump();

    expect(fondo(), coloresOscuros.crema);
  });
}
