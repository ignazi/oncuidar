// Categorías de intensidad de un síntoma (CA-08.3): 0 sin síntoma, 1 a 3 leve,
// 4 a 6 moderado, 7 a 9 severo y 10 insoportable.

import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/caracteristicas/registro_clinico/dominio/registro_clinico.dart';

void main() {
  group('EntradaSintoma.etiquetaPara', () {
    final esperado = {
      0: 'Sin síntoma',
      1: 'Leve',
      2: 'Leve',
      3: 'Leve',
      4: 'Moderado',
      5: 'Moderado',
      6: 'Moderado',
      7: 'Severo',
      8: 'Severo',
      9: 'Severo',
      10: 'Insoportable',
    };

    for (final MapEntry(key: intensidad, value: etiqueta) in esperado.entries) {
      test('$intensidad es «$etiqueta»', () {
        expect(EntradaSintoma.etiquetaPara(intensidad), etiqueta);
      });
    }

    test('las once intensidades caen en exactamente cinco categorías', () {
      final categorias = {
        for (var i = 0; i <= 10; i++) EntradaSintoma.etiquetaPara(i),
      };
      expect(categorias, hasLength(5));
    });
  });
}
