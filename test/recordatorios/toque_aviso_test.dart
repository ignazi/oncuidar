// Toque de un aviso de recordatorio con la app viva o cerrada: el enganche real
// de OncuidarApp con el servicio de notificaciones y el destino de arranque.

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/app/enrutador/destino_aviso.dart';
import 'package:oncuidar/main.dart';
import 'package:oncuidar/nucleo/notificaciones/servicio_notificaciones.dart';
import 'package:oncuidar/nucleo/proveedores.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayudas_recordatorios.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EstadoArranque.reiniciar();
  });
  tearDown(EstadoArranque.reiniciar);

  testWidgets('la app engancha el toque y conserva el aviso que la abrió', (
    tester,
  ) async {
    final notif = NotificacionesFalsas()
      // La app estaba cerrada y el usuario tocó el aviso de un recordatorio.
      ..payloadLanzamiento = ServicioNotificaciones.rutaAviso;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
          servicioNotificacionesProvider.overrideWithValue(notif),
        ],
        child: const OncuidarApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // El payload del arranque quedó registrado como destino pendiente.
    expect(EstadoArranque.destinoPendiente, '/recordatorios');
    expect(EstadoArranque.consumirDestino(), '/recordatorios');

    // El servicio quedó con el enganche del toque para cuando la app esté viva.
    expect(notif.alTocar, isNotNull);

    // Tocar otro aviso con la sesión cerrada tampoco navega: lo deja pendiente.
    notif.alTocar!(ServicioNotificaciones.rutaAviso);
    await tester.pumpAndSettle();
    expect(EstadoArranque.destinoPendiente, '/recordatorios');

    // Un payload ausente o externo se ignora sin romper la app.
    notif.alTocar!(null);
    notif.alTocar!('https://sitio-externo.cl');
    await tester.pumpAndSettle();
    expect(EstadoArranque.destinoPendiente, '/recordatorios');
    expect(tester.takeException(), isNull);
  });
}
