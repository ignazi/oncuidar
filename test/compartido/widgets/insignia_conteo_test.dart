import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/compartido/widgets/insignia_conteo.dart';

Widget _envolver(Widget hijo) => MaterialApp(
  home: Scaffold(body: Center(child: hijo)),
);

/// Relación de contraste entre dos colores (WCAG).
double _contraste(Color a, Color b) {
  final claro = a.computeLuminance() > b.computeLuminance() ? a : b;
  final oscuro = identical(claro, a) ? b : a;
  return (claro.computeLuminance() + 0.05) / (oscuro.computeLuminance() + 0.05);
}

void main() {
  tearDown(() => Paleta.usar(coloresClaros));

  testWidgets('muestra el total y pasa de 99 a «99+»', (tester) async {
    await tester.pumpWidget(_envolver(const InsigniaConteo(total: 7)));
    expect(find.text('7'), findsOneWidget);

    await tester.pumpWidget(_envolver(const InsigniaConteo(total: 150)));
    expect(find.text('99+'), findsOneWidget);
  });

  for (final (nombre, colores) in [
    ('claro', coloresClaros),
    ('oscuro', coloresOscuros),
  ]) {
    test('el número se lee sobre el fondo en modo $nombre', () {
      Paleta.usar(colores);
      final fondo = InsigniaConteo.colorEncabezado();
      // 4.5 es el mínimo recomendado para texto; el número es grande y en negrita.
      expect(_contraste(coloresClaros.textoPrincipal, fondo), greaterThan(4.5));
    });
  }
}
