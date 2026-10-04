import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Nombre del archivo exportado: historial_oncuidar_AAAA-MM-DD_HHMM.ext.
String nombreArchivoExportacion(DateTime ahora, String extension) {
  final mes = ahora.month.toString().padLeft(2, '0');
  final dia = ahora.day.toString().padLeft(2, '0');
  final fecha = '${ahora.year}-$mes-$dia';
  final hora =
      '${ahora.hour.toString().padLeft(2, '0')}${ahora.minute.toString().padLeft(2, '0')}';
  return 'historial_oncuidar_${fecha}_$hora.$extension';
}

/// Escribe el archivo en la carpeta temporal y lo devuelve.
Future<File> escribirArchivoTemporal(Uint8List bytes, String extension) async {
  final dir = await getTemporaryDirectory();
  final archivo = File(
    '${dir.path}${Platform.pathSeparator}'
    '${nombreArchivoExportacion(DateTime.now(), extension)}',
  );
  await archivo.writeAsBytes(bytes, flush: true);
  return archivo;
}

/// Abre el menú del sistema para compartir el archivo exportado.
Future<void> compartirArchivoExportado(
  Uint8List bytes,
  String extension,
) async {
  final archivo = await escribirArchivoTemporal(bytes, extension);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(archivo.path)],
      subject: 'Historial clínico OnCuidar',
      text: 'Historial clínico OnCuidar',
    ),
  );
}
