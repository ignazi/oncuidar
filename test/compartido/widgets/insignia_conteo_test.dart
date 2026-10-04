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

  test('el número blanco se lee sobre el fondo de la insignia', () {
    // 4.5 es el mínimo recomendado para texto; aquí el número es negrita y grande.
    expect(
      _contraste(InsigniaConteo.colorNumero, InsigniaConteo.colorFondo),
      greaterThan(4.5),
    );
  });

  for (final (nombre, colores) in [
    ('claro', coloresClaros),
    ('oscuro', coloresOscuros),
  ]) {
    testWidgets('el aro separa la insignia del degradado en modo $nombre', (
      tester,
    ) async {
      Paleta.usar(colores);
      await tester.pumpWidget(_envolver(const InsigniaConteo(total: 3)));

      final decoracion =
          tester.widget<Container>(find.byType(Container)).decoration!
              as BoxDecoration;
      expect(decoracion.color, InsigniaConteo.colorFondo);
      expect((decoracion.border! as Border).top.color, colores.tarjeta);
      // El fondo no es ninguno de los dorados del degradado.
      for (final dorado in Paleta.degradadoCabecera.colors) {
        expect(decoracion.color, isNot(dorado));
      }
    });
  }
}
