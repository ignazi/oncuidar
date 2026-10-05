import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/caracteristicas/registro_clinico/datos/repositorio_registros_clinicos.dart';

import '../../../ayudas/exportacion.dart';

// Exportación del historial (HU-12/13) de punta a punta: se exporta desde la
// pantalla, se comparte el archivo generado y se lee ese archivo para comprobar
// su contenido real (orden y cantidad de filas).

void main() {
  testWidgets('exportar abre el archivo directo, sin menú de Abrir o Compartir', (
    tester,
  ) async {
    tallerDePrueba(tester);
    final (base, cifrado, activo, _) = await baseConDosPacientes();
    instalarCanalesDeExportacion();
    await RepositorioRegistrosClinicos(base).guardarRegistroClinico(
      activo,
      registroDe('2026-09-01', activo, DateTime(2026, 9, 1, 8)),
    );

    await tester.pumpWidget(
      pantallaHistorial(base, cifrado, pacienteActivo: activo),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Exportar PDF'));
    await esperarHasta(tester, find.byKey(const Key('compartirVisorPdf')));

    // Nada de menú: el visor ya está abierto, con compartir y descargar en la barra.
    expect(find.text('Abrir archivo'), findsNothing);
    expect(find.byKey(const Key('botonAbrirExportacion')), findsNothing);
    expect(find.byKey(const Key('botonCompartirExportacion')), findsNothing);
    expect(find.byKey(const Key('compartirVisorPdf')), findsOneWidget);
    expect(find.byKey(const Key('descargarVisorPdf')), findsOneWidget);
  });

  testWidgets('las palabras PDF y Excel son blancas también en modo oscuro', (
    tester,
  ) async {
    tallerDePrueba(tester);
    Paleta.usar(coloresOscuros);
    addTearDown(() => Paleta.usar(coloresClaros));
    final (base, cifrado, activo, _) = await baseConDosPacientes();
    instalarCanalesDeExportacion();
    await RepositorioRegistrosClinicos(base).guardarRegistroClinico(
      activo,
      registroDe('2026-09-01', activo, DateTime(2026, 9, 1, 8)),
    );

    await tester.pumpWidget(
      pantallaHistorial(base, cifrado, pacienteActivo: activo),
    );
    await tester.pumpAndSettle();

    for (final nombre in ['PDF', 'Excel']) {
      final texto = tester.widget<Text>(find.text(nombre));
      expect(texto.style!.color, Colors.white, reason: 'palabra «$nombre»');
    }
  });
}
