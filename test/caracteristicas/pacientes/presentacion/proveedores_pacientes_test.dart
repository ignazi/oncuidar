// Paciente activo (CA-07.2): la selección se guarda en el teléfono y se
// recupera al volver a abrir la aplicación.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/caracteristicas/pacientes/presentacion/proveedores_pacientes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Espera a que el valor del proveedor cumpla la condición.
Future<void> _esperar(bool Function() condicion) async {
  for (var i = 0; i < 100; i++) {
    if (condicion()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('La condición no se cumplió a tiempo');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('el paciente elegido sigue seleccionado tras reiniciar', () async {
    final antes = ProviderContainer();
    await antes.read(selectedPatientIdProvider.notifier).select('paciente-b');
    expect(antes.read(selectedPatientIdProvider), 'paciente-b');
    antes.dispose();

    // Un contenedor nuevo equivale a volver a abrir la aplicación.
    final despues = ProviderContainer();
    addTearDown(despues.dispose);
    despues.read(selectedPatientIdProvider);
    await _esperar(
      () => despues.read(selectedPatientIdProvider) == 'paciente-b',
    );
  });

  test('al quitar la selección no queda nada guardado', () async {
    final antes = ProviderContainer();
    await antes.read(selectedPatientIdProvider.notifier).select('paciente-a');
    await antes.read(selectedPatientIdProvider.notifier).select(null);
    antes.dispose();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_patient_id'), isNull);
    final despues = ProviderContainer();
    addTearDown(despues.dispose);
    expect(despues.read(selectedPatientIdProvider), isNull);
  });
}
