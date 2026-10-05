import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oncuidar/caracteristicas/historial/presentacion/pantalla_vista_excel.dart';
import 'package:oncuidar/caracteristicas/pacientes/dominio/paciente.dart';
import 'package:oncuidar/caracteristicas/registro_clinico/dominio/registro_clinico.dart';
import 'package:oncuidar/compartido/widgets/visor_con_zoom.dart';

// La hoja de Excel dentro de la app: misma ficha, resumen y tabla del archivo.

DatosHojaExcel _datos({
  DateTime? inicio,
  DateTime? fin,
  int cantidad = 3,
  String observaciones = 'Paciente estable durante el día',
}) {
  final base = DateTime(2026, 10, 4, 9);
  return DatosHojaExcel(
    registros: [
      for (var i = 0; i < cantidad; i++)
        RegistroClinico(
          id: 'r$i',
          pacienteId: 'p',
          // Se dan desordenados: la hoja los muestra del más antiguo al reciente.
          fecha: base.add(Duration(days: cantidad - i)),
          creadoEn: base.add(Duration(days: cantidad - i)),
          tipoRegistro: 'programado',
          nivelAlerta: NivelAlerta.values[i % 3],
          observaciones: '$observaciones $i',
          signosVitales: const SignosVitales(temperatura: 38.2),
        ),
    ],
    paciente: Paciente(
      id: 'p',
      nombreCompleto: 'Paciente Test',
      centroSaludNombre: 'Hospital Pediátrico',
      contactoEmergenciaNombre: 'María Test',
      creadoEn: DateTime(2026, 1, 1),
    ),
    nombreCuidador: 'Ana Torres',
    fechaInicio: inicio,
    fechaFin: fin,
    generadoEn: DateTime(2026, 10, 8, 20, 15),
  );
}

Future<void> _abrir(
  WidgetTester tester,
  DatosHojaExcel datos, {
  Size tamano = const Size(360, 800),
  VoidCallback? alCompartir,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: PantallaVistaExcel(datos: datos, alCompartir: alCompartir),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra el título, la ficha y el resumen', (tester) async {
    await _abrir(tester, _datos(inicio: DateTime(2026, 10, 4)));

    for (final texto in [
      'HISTORIAL ONCUIDAR',
      'PACIENTE',
      'CUIDADOR',
      'CENTRO DE SALUD',
      'CONTACTO DE EMERGENCIA',
      'RESUMEN',
      'Ana Torres',
      'Hospital Pediátrico',
    ]) {
      expect(find.text(texto), findsWidgets, reason: 'falta «$texto»');
    }
  });

  testWidgets('el resumen dice el día o el rango filtrado', (tester) async {
    await _abrir(tester, _datos(inicio: DateTime(2026, 10, 4)));
    expect(find.text('Día'), findsOneWidget);
    expect(find.text('Domingo 04/10/2026'), findsOneWidget);

    await _abrir(
      tester,
      _datos(inicio: DateTime(2026, 10, 4), fin: DateTime(2026, 10, 7)),
    );
    expect(find.text('Período'), findsOneWidget);
    expect(find.text('Del 04-10-2026 al 07-10-2026'), findsOneWidget);
  });

  testWidgets('la tabla trae los encabezados y una fila por registro', (
    tester,
  ) async {
    await _abrir(tester, _datos(cantidad: 4));

    for (final encabezado in ['Fecha', 'Hora', 'Estado', 'Temp.', 'Síntomas']) {
      expect(find.text(encabezado), findsOneWidget);
    }
    expect(find.text('Sat. O₂'), findsOneWidget);
    // Una fila de la hoja por registro.
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(Key('filaRegistroExcel_$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('filaRegistroExcel_4')), findsNothing);
    expect(find.text('38.2°C'), findsNWidgets(4));
  });

  testWidgets('las filas salen del registro más antiguo al más reciente', (
    tester,
  ) async {
    await _abrir(tester, _datos(cantidad: 3));

    double y(String texto) => tester.getTopLeft(find.text(texto)).dy;
    // Observación 2 es la del día más antiguo, la 0 la del más reciente.
    expect(
      y('Paciente estable durante el día 2'),
      lessThan(y('Paciente estable durante el día 1')),
    );
    expect(
      y('Paciente estable durante el día 1'),
      lessThan(y('Paciente estable durante el día 0')),
    );
  });

  testWidgets('ninguna palabra queda cortada: la fila crece con el texto', (
    tester,
  ) async {
    await _abrir(tester, _datos(cantidad: 1, observaciones: 'palabra ' * 60));

    final texto = find.textContaining('palabra');
    final fila = find.byKey(const Key('filaRegistroExcel_0'));
    // El texto entero queda dentro de su fila (no se recorta por abajo).
    expect(
      tester.getRect(texto).bottom,
      lessThanOrEqualTo(tester.getRect(fila).bottom + 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el texto largo se reparte en varias líneas dentro de su celda', (
    tester,
  ) async {
    await _abrir(tester, _datos(cantidad: 1, observaciones: 'palabra ' * 30));

    final observacion = find.textContaining('palabra');
    final alto = tester.getSize(observacion).height;
    // Una línea mide ~16; varias líneas la superan con holgura.
    expect(alto, greaterThan(40));
    // Y cabe en el ancho de su columna (44 caracteres × 8 px).
    expect(tester.getSize(observacion).width, lessThanOrEqualTo(44 * 8.0));
  });

  testWidgets('la hoja se puede acercar y mover sin desbordar la pantalla', (
    tester,
  ) async {
    await _abrir(tester, _datos(cantidad: 6), tamano: const Size(320, 568));
    expect(tester.takeException(), isNull);

    final zoom = find.byKey(const Key('zoomVistaExcel'));
    await tester.drag(zoom, const Offset(-400, -200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final visor = tester.widget<InteractiveViewer>(zoom);
    expect(visor.constrained, isFalse);
    expect(visor.minScale, lessThan(1));
    expect(visor.maxScale, greaterThan(1));
  });

  testWidgets('compartir y volver funcionan', (tester) async {
    var compartido = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => abrirVistaExcel(
              context,
              datos: _datos(),
              alCompartir: () => compartido++,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('compartirVistaExcel')));
    expect(compartido, 1);

    await tester.tap(find.byKey(const Key('cerrarVistaExcel')));
    await tester.pumpAndSettle();
    expect(find.byType(PantallaVistaExcel), findsNothing);
  });

  testWidgets('sin acción de compartir no hay botón', (tester) async {
    await _abrir(tester, _datos());
    expect(find.byKey(const Key('compartirVistaExcel')), findsNothing);
  });

  testWidgets(
    'se ve como Excel: letras de columna, números de fila y pestaña',
    (tester) async {
      await _abrir(tester, _datos());

      for (final letra in ['A', 'B', 'E', 'J']) {
        expect(find.text(letra), findsOneWidget, reason: 'columna $letra');
      }
      // Números de fila a la izquierda: el 1 es el título.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // Sin pestaña al pie: no aporta nada en la app.
      expect(find.text('Historial'), findsNothing);
      // Cada celda de la tabla tiene su propio recuadro (cuadrícula).
      final fila = find.byKey(const Key('filaRegistroExcel_0'));
      final celdas = find.descendant(
        of: fila,
        matching: find.byType(Container),
      );
      expect(celdas.evaluate().length, greaterThanOrEqualTo(11));
    },
  );

  testWidgets('la barra superior usa el degradado dorado de la app', (
    tester,
  ) async {
    await _abrir(tester, _datos());
    final cajas = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      cajas.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).gradient != null,
      ),
      isTrue,
    );
  });

  group('zoom a gusto', () {
    double escala(WidgetTester tester) =>
        tester.state<EstadoVisorConZoom>(find.byType(VisorConZoom)).escalaTotal;

    testWidgets('abre con una escala legible', (tester) async {
      await _abrir(tester, _datos());
      expect(escala(tester), closeTo(zoomInicialHoja, 1e-9));
    });

    testWidgets('los botones acercan y alejan', (tester) async {
      await _abrir(tester, _datos());
      final inicial = escala(tester);

      await tester.tap(find.byKey(const Key('zoomMas')));
      await tester.pump();
      expect(escala(tester), greaterThan(inicial));

      await tester.tap(find.byKey(const Key('zoomMenos')));
      await tester.tap(find.byKey(const Key('zoomMenos')));
      await tester.pump();
      expect(escala(tester), lessThan(inicial));
    });

    testWidgets('se puede acercar hasta el máximo y alejar hasta el mínimo', (
      tester,
    ) async {
      await _abrir(tester, _datos());

      for (var i = 0; i < 15; i++) {
        await tester.tap(find.byKey(const Key('zoomMas')));
      }
      await tester.pump();
      expect(escala(tester), closeTo(zoomMaximoHoja, 1e-9));

      for (var i = 0; i < 30; i++) {
        await tester.tap(find.byKey(const Key('zoomMenos')));
      }
      await tester.pump();
      // Lo más lejos es ver toda la hoja a lo ancho de la pantalla.
      expect(escala(tester), lessThan(0.4));
      final hoja = tester.getRect(find.byKey(const Key('hojaExcel')));
      expect(hoja.width, closeTo(360, 1));
    });

    testWidgets('«Ajustar» deja toda la hoja a lo ancho de la pantalla', (
      tester,
    ) async {
      await _abrir(tester, _datos(), tamano: const Size(360, 800));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('zoomMas')));
      }
      await tester.pump();

      await tester.tap(find.byKey(const Key('zoomAjustar')));
      await tester.pump();

      // getRect incluye la escala del zoom (getSize daría el tamaño sin escalar).
      final hoja = tester.getRect(find.byKey(const Key('hojaExcel')));
      // La hoja, ya escalada, cabe en el ancho de la pantalla.
      expect(hoja.width, lessThanOrEqualTo(360));
      expect(hoja.width, greaterThan(360 * 0.8));
    });

    testWidgets('doble toque acerca y otro doble toque vuelve a ajustar', (
      tester,
    ) async {
      await _abrir(tester, _datos());
      final zona = find.byKey(const Key('zoomVistaExcel'));
      final antes = escala(tester);

      await tester.tap(zona);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(zona);
      await tester.pumpAndSettle();
      expect(escala(tester), greaterThan(antes));

      await tester.tap(zona);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(zona);
      await tester.pumpAndSettle();
      expect(escala(tester), lessThan(1.2));
    });

    testWidgets('el rango de zoom del visor es amplio', (tester) async {
      await _abrir(tester, _datos());
      // Los límites del visor son relativos a lo ya dibujado: por la escala total.
      final visor = tester.widget<InteractiveViewer>(
        find.byKey(const Key('zoomVistaExcel')),
      );
      final dibujado = escala(tester);
      expect(visor.maxScale * dibujado, closeTo(zoomMaximoHoja, 1e-9));
      expect(visor.minScale * dibujado, lessThan(0.4));
      expect(zoomMaximoHoja, greaterThanOrEqualTo(6));
    });

    testWidgets('el botón de descargar solo aparece si se da la acción', (
      tester,
    ) async {
      await _abrir(tester, _datos());
      expect(find.byKey(const Key('descargarVistaExcel')), findsNothing);
    });
  });

  testWidgets('los datos cortos van en una sola línea, sin partir palabras', (
    tester,
  ) async {
    // Letra grande del teléfono: aun así «Programado» no se parte.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 800),
          textScaler: TextScaler.linear(1.6),
        ),
        child: MaterialApp(home: PantallaVistaExcel(datos: _datos())),
      ),
    );
    await tester.pumpAndSettle();

    for (final texto in ['Programado', 'Normal', 'Alerta', '38.2°C']) {
      final celda = find.text(texto).first;
      final parrafo = tester.renderObject<RenderParagraph>(celda);
      final lineas = parrafo.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: texto.length),
      );
      final filas = lineas.map((c) => c.top.round()).toSet();
      expect(filas, hasLength(1), reason: '«$texto» se partió en dos líneas');
      expect(parrafo.didExceedMaxLines, isFalse, reason: '«$texto» no cabe');
    }
  });

  testWidgets('al acercar, la hoja se redibuja más grande (texto nítido)', (
    tester,
  ) async {
    await _abrir(tester, _datos());
    double tamanoLetra() =>
        tester.widget<Text>(find.text('HISTORIAL ONCUIDAR')).style!.fontSize!;
    final antes = tamanoLetra();

    await tester.tap(find.byKey(const Key('zoomMas')));
    await tester.pumpAndSettle();

    // La letra se dibuja más grande (no es la misma imagen estirada).
    expect(tamanoLetra(), closeTo(antes * 1.5, 0.01));
  });

  testWidgets('tiene el botón para girar a pantalla completa', (tester) async {
    await _abrir(tester, _datos());
    expect(find.byKey(const Key('girarVisor')), findsOneWidget);
  });
}
