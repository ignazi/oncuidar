import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/app/tema/paleta.dart';

/// Relación de contraste WCAG entre dos colores (1 a 21).
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  tearDown(() => Paleta.usar(coloresClaros));

  group('Contraste del modo oscuro (4,5 es el mínimo para texto)', () {
    const c = coloresOscuros;
    final fondos = {
      'crema': c.crema,
      'tarjeta': c.tarjeta,
      'fondoEntrada': c.fondoEntrada,
      'doradoClaro': c.doradoClaro,
    };
    final textos = {
      'textoPrincipal': c.textoPrincipal,
      'textoSecundario': c.textoSecundario,
      'doradoOscuro (texto e íconos)': c.doradoOscuro,
    };

    for (final texto in textos.entries) {
      for (final fondo in fondos.entries) {
        test('${texto.key} sobre ${fondo.key}', () {
          expect(
            contraste(texto.value, fondo.value),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    }

    test('textoAyuda (pistas) sobre tarjeta y campos', () {
      expect(contraste(c.textoAyuda, c.tarjeta), greaterThanOrEqualTo(4.5));
      expect(
        contraste(c.textoAyuda, c.fondoEntrada),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('el café sobre dorado se lee sobre todos los rellenos', () {
      for (final dorado in [
        c.doradoPrincipal,
        c.doradoMedio,
        Paleta.doradoRelleno,
      ]) {
        expect(contraste(c.sobreDorado, dorado), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group(
    'Contraste del modo claro (el diseño original, solo se verifica lo propio)',
    () {
      const c = coloresClaros;

      test(
        'el texto principal y el terciario se leen sobre las superficies',
        () {
          for (final fondo in [
            c.crema,
            c.tarjeta,
            c.fondoEntrada,
            c.doradoClaro,
          ]) {
            expect(contraste(c.textoPrincipal, fondo), greaterThanOrEqualTo(7));
          }
          for (final fondo in [c.crema, c.tarjeta]) {
            expect(
              contraste(c.textoTerciario, fondo),
              greaterThanOrEqualTo(4.5),
            );
          }
        },
      );
    },
  );

  group('Insignia con número', () {
    for (final (nombre, c) in [
      ('claro', coloresClaros),
      ('oscuro', coloresOscuros),
    ]) {
      test('en modo $nombre: número legible y fondo que destaca', () {
        Paleta.usar(c);
        const numero = Color(0xFFFFFFFF);
        // El número blanco sobre el fondo de la insignia.
        expect(contraste(numero, Paleta.insignia), greaterThanOrEqualTo(4.5));
        // El fondo se distingue de su aro claro (que la separa del botón y del
        // degradado) y del dorado del encabezado.
        expect(
          contraste(Paleta.insignia, Paleta.aroInsignia),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contraste(Paleta.insignia, Paleta.doradoPrincipal),
          greaterThanOrEqualTo(2.0),
        );
        // El aro se ve contra el botón oscuro; en claro es blanco sobre blanco y
        // la insignia ya contrasta 8:1 con él.
        if (c.oscuro) {
          expect(
            contraste(Paleta.aroInsignia, Paleta.tarjeta),
            greaterThanOrEqualTo(4.5),
          );
        }
      });
    }
  });
}
