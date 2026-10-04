import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/caracteristicas/chat/dominio/conversacion.dart';
import 'package:oncuidar/nucleo/utilidades/formato_fecha.dart';

void main() {
  group('MensajeConversacion', () {
    test('conserva la hora de envío al guardar y leer', () {
      final enviado = DateTime(2026, 10, 4, 21, 30);
      final mensaje = MensajeConversacion(
        texto: 'Hola',
        delUsuario: true,
        enviadoEn: enviado,
      );

      final leido = MensajeConversacion.desdeMapa(mensaje.aMapa());

      expect(leido.enviadoEn, enviado);
    });

    test('un mensaje guardado antes de existir la hora se lee sin ella', () {
      final leido = MensajeConversacion.desdeMapa({
        'texto': 'Antiguo',
        'delUsuario': false,
      });

      expect(leido.enviadoEn, isNull);
      expect(leido.aMapa().containsKey('enviadoEn'), isFalse);
    });
  });

  group('etiquetaDia', () {
    final ahora = DateTime(2026, 10, 4, 12);

    test('hoy y ayer se nombran', () {
      expect(etiquetaDia(DateTime(2026, 10, 4, 1), ahora), 'Hoy');
      expect(etiquetaDia(DateTime(2026, 10, 3, 23), ahora), 'Ayer');
    });

    test('un día anterior muestra la fecha larga', () {
      expect(etiquetaDia(DateTime(2026, 10, 1), ahora), 'Jueves 01/10/2026');
    });
  });
}
