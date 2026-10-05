import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xlsx;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/pantalla_visor_pdf.dart';
import 'package:oncuidar/caracteristicas/historial/presentacion/pantalla_historial.dart';
import 'package:oncuidar/caracteristicas/pacientes/datos/repositorio_pacientes.dart';
import 'package:oncuidar/caracteristicas/pacientes/dominio/paciente.dart';
import 'package:oncuidar/caracteristicas/pacientes/presentacion/proveedores_pacientes.dart';
import 'package:oncuidar/caracteristicas/perfil/datos/repositorio_cuidador.dart';
import 'package:oncuidar/caracteristicas/registro_clinico/dominio/registro_clinico.dart';
import 'package:oncuidar/nucleo/cifrado/servicio_cifrado.dart';
import 'package:oncuidar/nucleo/datos/base_datos_segura.dart';
import 'package:oncuidar/nucleo/proveedores.dart';

// Ayudas para probar la exportación del historial de punta a punta: se deja
// generar el archivo, se comparte (canal simulado) y se lee el archivo real.

const clavePrueba = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=';
const uidPrueba = 'uid-1';

MockFirebaseAuth authPrueba() => MockFirebaseAuth(
  mockUser: MockUser(uid: uidPrueba, email: 'cuidador@test.cl'),
);

/// Registro cuyo texto de observaciones lleva la fecha, para que el orden del
/// archivo se pueda comprobar sin ambigüedad.
RegistroClinico registroDe(String id, String idPaciente, DateTime momento) =>
    RegistroClinico(
      id: id,
      pacienteId: idPaciente,
      fecha: momento,
      creadoEn: momento,
      tipoRegistro: 'programado',
      observaciones: 'obs-$id',
    );

Future<(BaseDatosSegura, ServicioCifrado, String activo, String otro)>
baseConDosPacientes() async {
  final cifrado = ServicioCifrado(clavePrueba: clavePrueba);
  await cifrado.fijarClave(uidPrueba, clavePrueba);
  final base = BaseDatosSegura(
    base: FakeFirebaseFirestore(),
    uidPrueba: uidPrueba,
    cifrado: cifrado,
  );
  await RepositorioCuidador(base).crearCuidador({
    'nombre': 'Ana Torres',
    'correo': 'cuidador@test.cl',
    'telefono': '+56 9 1111 1111',
    'relacion': 'Madre',
    'direccion': 'Av. Siempre Viva 742',
  });
  // El id lo genera Firestore, así que se usan los que devuelve.
  final activo = await RepositorioPacientes(base).crearPaciente(
    Paciente(
      id: '',
      nombreCompleto: 'Paciente A',
      creadoEn: DateTime(2026, 1, 1),
    ),
  );
  final otro = await RepositorioPacientes(base).crearPaciente(
    Paciente(
      id: '',
      nombreCompleto: 'Paciente B',
      creadoEn: DateTime(2026, 1, 2),
    ),
  );
  return (base, cifrado, activo, otro);
}

/// Fija el paciente activo: los ids automáticos no garantizan el orden.
class PacienteActivoFijo extends PacienteSeleccionadoNotifier {
  PacienteActivoFijo(this.idActivo);

  final String? idActivo;

  @override
  String? build() => idActivo;
}

Widget pantallaHistorial(
  BaseDatosSegura base,
  ServicioCifrado cifrado, {
  required String pacienteActivo,
  List<Override> overridesExtra = const [],
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (c, s) => const HistorialScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (c, s) =>
            const Scaffold(body: Center(child: Text('Dashboard'))),
      ),
      GoRoute(
        path: '/registro-clinico',
        builder: (c, s) => const Scaffold(
          body: Center(child: Text('Registro clínico abierto')),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      firebaseAuthProvider.overrideWithValue(authPrueba()),
      servicioCifradoProvider.overrideWithValue(cifrado),
      baseDatosSeguraProvider.overrideWith((_) => base),
      idPacienteSeleccionadoProvider.overrideWith(
        () => PacienteActivoFijo(pacienteActivo),
      ),
      // pdfx no se puede dibujar en pruebas: un documento falso lo reemplaza.
      constructorDocumentoPdfProvider.overrideWithValue(
        (ruta) => Center(child: Text('documento en $ruta')),
      ),
      ...overridesExtra,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void tallerDePrueba(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Simula la carpeta temporal y el canal de compartir, y devuelve la lista de
/// archivos compartidos (en el mismo orden en que se invocan).
List<String> instalarCanalesDeExportacion({
  List<Map<Object?, Object?>>? guardados,
}) {
  final compartidos = <String>[];
  final temporal = Directory.systemTemp.createTempSync('oncuidar_exportacion');
  // No se borra: GoogleFonts deja la fuente cargada y el archivo queda en uso.
  sembrarFuentesEnDisco(temporal);

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => temporal.path,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async {
          final args = call.arguments as Map<Object?, Object?>;
          compartidos.addAll((args['paths'] as List<Object?>).cast<String>());
          return 'compartido';
        },
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_file_dialog'), (
        call,
      ) async {
        if (call.method != 'saveFile') return null;
        final args = call.arguments as Map<Object?, Object?>;
        guardados?.add(args);
        // El nombre que el usuario ve en «Guardar como».
        return '/storage/emulated/0/Download/${args['fileName']}';
      });
  return compartidos;
}

/// Evita que GoogleFonts intente descargar Nunito por red (no hay red en tests).
/// El nombre del archivo lo arma el propio paquete como `Nunito_<peso>_<hash>.ttf`
/// y el motor acepta cualquier byte como fuente en el binding de pruebas, así que
/// se siembran todas las combinaciones de variantes y hashes de la familia.
void sembrarFuentesEnDisco(Directory destino) {
  for (final peso in _variantesDeNunito) {
    for (final hash in _hashesDeNunito) {
      File(
        '${destino.path}${Platform.pathSeparator}Nunito_${peso}_$hash.ttf',
      ).writeAsBytesSync(Uint8List.fromList([0, 1, 0, 0]));
    }
  }
}

const _variantesDeNunito = [
  'regular',
  'italic',
  '100',
  '100italic',
  '200',
  '200italic',
  '300',
  '300italic',
  '400',
  '400italic',
  '500',
  '500italic',
  '600',
  '600italic',
  '700',
  '700italic',
  '800',
  '800italic',
  '900',
  '900italic',
];

const _hashesDeNunito = [
  '8d32053d727702a77e28b4104b53fb30333f146ef22ed73ebae6a509f94d885c',
  '6f96017e762896b4cf3c2db345d41d7a72a3720a95698c3cd47020bf433db435',
  '1f6452d3509db129d3468088c1c952f1a844b6dc865703a09595fc53700a6251',
  'f165190d31319dc6384c83fdd014ed983630541b21d005b5caadf1d74fbd513d',
  '8148a236e4127dad38346ce596c544389aa2fdaaa9f311e589741de30d25ddb8',
  '43364ac2d05d1033b5e255ce77e4d84d2f6467bfadb5e5985ca4e688949e73bf',
  'a5ddd59da28c281984ae3bd12aa3b9af3b204e61156e50f1108d5fcf71aa5665',
  '00fe8a871f3548a3d11273596486ff1c30328c3e6853d2f43f0e72c75802b24a',
  'd49777748d078c1787b1f8e9d14317a0cf4510039c86ebee7b74a037d4758b00',
  'df3c491d67e881e1b0c6265a7a8364f07e38d7a25893e9b2beac1439e1c2efd9',
  '56984ce135b93b61a7e1176b810c8afbaafbcdce625fca628b73dc16139f7a7a',
  'a5337453969dd598f31a7bfd0bb8c66aece01b0f7d5bffa9f2d1d2eb020ae9f9',
  '1d9670625be9c432a93d3467f99c5aa3e5626181c27d6d9a27285781539dfd83',
  '170f35fc695e39b13b53b58452f1a9e334277f3633c4ab89346db743b6b4923f',
  '3fff73610e77b1bca1edd861e4830865d147de46cffc685fb253cb050b1148a5',
];

/// Espera real (disco y generación) hasta que [aparece] exista en pantalla.
Future<void> esperarHasta(WidgetTester tester, Finder aparece) async {
  for (var vuelta = 0; vuelta < 100 && aparece.evaluate().isEmpty; vuelta++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pumpAndSettle();
}

/// Exporta desde la pantalla: se abre el visor del archivo y, desde su barra, se
/// comparte. Devuelve los bytes del archivo compartido.
Future<Uint8List> exportarDesdeLaPantalla(
  WidgetTester tester,
  String boton,
  List<String> compartidos,
) async {
  await tester.tap(find.byTooltip(boton));
  final compartirPdf = find.byKey(const Key('compartirVisorPdf'));
  final compartirExcel = find.byKey(const Key('compartirVistaExcel'));
  // Generar el archivo es espera real: el visor aparece cuando está listo.
  for (
    var vuelta = 0;
    vuelta < 100 &&
        compartirPdf.evaluate().isEmpty &&
        compartirExcel.evaluate().isEmpty;
    vuelta++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pumpAndSettle();
  await tester.tap(
    compartirPdf.evaluate().isNotEmpty ? compartirPdf : compartirExcel,
  );
  for (var vuelta = 0; vuelta < 50 && compartidos.isEmpty; vuelta++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  expect(
    compartidos,
    hasLength(1),
    reason: 'debería haberse compartido un archivo',
  );
  final leido = await tester.runAsync(
    () => File(compartidos.single).readAsBytes(),
  );
  expect(leido, isNotNull);
  return leido!;
}

/// Texto visible del PDF: `pdf` comprime los streams, así que se inflan y se
/// leen los operandos de los operadores de texto (`Tj` y `TJ`).
String textoPdf(Uint8List bytes) => fragmentosPdf(bytes).join();

/// Cada fragmento tal como lo dibuja `pdf`: una fecha puede partirse en varios.
List<String> fragmentosPdf(Uint8List bytes) {
  final palabras = <String>[];
  for (final trozo in _trozosDelPdf(bytes)) {
    for (final operador in RegExp(
      r'\[(.*?)\]\s*TJ|\((?:\\.|[^\\()])*\)\s*Tj',
      dotAll: true,
    ).allMatches(trozo)) {
      if (operador.group(1) == null) {
        palabras.add(_sinParentesis(operador.group(0)!));
        continue;
      }
      for (final palabra in RegExp(
        r'\((?:\\.|[^\\()])*\)',
      ).allMatches(operador.group(1)!)) {
        palabras.add(_sinParentesis(palabra.group(0)!));
      }
    }
  }
  return palabras;
}

/// Contenido del PDF tal cual y con los streams inflados.
List<String> _trozosDelPdf(Uint8List bytes) {
  final crudo = latin1.decode(bytes, allowInvalid: true);
  final trozos = <String>[crudo];
  for (final bloque in RegExp(
    r'stream\r?\n(.*?)endstream',
    dotAll: true,
  ).allMatches(crudo)) {
    try {
      final inflado = zlib.decode(latin1.encode(bloque.group(1)!));
      trozos.add(latin1.decode(inflado, allowInvalid: true));
    } catch (_) {
      continue;
    }
  }
  return trozos;
}

String _sinParentesis(String operandos) {
  final limites = operandos.indexOf('(');
  final cuerpo = limites < 0
      ? operandos
      : operandos.substring(limites + 1, operandos.lastIndexOf(')'));
  return cuerpo
      .replaceAll(r'\(', '(')
      .replaceAll(r'\)', ')')
      .replaceAll(r'\\', r'\');
}

/// Etiquetas de observaciones que dibuja el PDF, en el orden dibujado.
List<String> observacionesPdf(Uint8List bytes, {required String prefijo}) {
  // Se busca por fragmento: unidos, los dígitos del siguiente se pegarían.
  final patron = RegExp('^$prefijo-[A-Za-z0-9-]+\$');
  return [
    for (final fragmento in fragmentosPdf(bytes))
      if (patron.hasMatch(fragmento.trim())) fragmento.trim(),
  ];
}

/// Fechas dd-mm-aaaaa presentes en el PDF que están entre las esperadas.
List<String> fechasEsperadasEnPdf(Uint8List bytes, Set<String> esperadas) {
  // Las etiquetas tipo obs-2026-09-01 se reemplazan por un espacio: sus dígitos simulan fechas.
  final etiqueta = RegExp(r'^[A-Za-z]+-\d{4}-\d{2}-\d{2}$');
  final texto = fragmentosPdf(
    bytes,
  ).map((f) => etiqueta.hasMatch(f.trim()) ? ' ' : f).join();
  return RegExp(r'\d{2}-\d{2}-\d{4}')
      .allMatches(texto)
      .map((m) => m.group(0)!)
      .where(esperadas.contains)
      .toList();
}

/// Columna de observaciones de las filas de datos de la hoja Historial.
List<String> observacionesExcel(Uint8List bytes) {
  final hoja = xlsx.Excel.decodeBytes(bytes)['Historial'];
  final filas = hoja.rows;
  final encabezado = filas.indexWhere(
    (f) => f.isNotEmpty && f.first?.value.toString() == 'Fecha',
  );
  return [
    for (final fila in filas.skip(encabezado + 1))
      if (fila.length > 9 && fila[9] != null) fila[9]!.value.toString(),
  ];
}
