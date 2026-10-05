import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';
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

/// Guarda el archivo en el teléfono con el selector «Guardar como» del sistema.
///
/// Devuelve true si se guardó y false si se canceló o no se pudo. No necesita
/// permisos de almacenamiento: el selector del sistema da acceso a la carpeta.
Future<bool> descargarArchivoExportado(
  Uint8List bytes,
  String extension,
) async {
  try {
    final ruta = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        data: bytes,
        fileName: nombreArchivoExportacion(DateTime.now(), extension),
        mimeTypesFilter: [
          extension == 'pdf'
              ? 'application/pdf'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ],
      ),
    );
    return ruta != null;
  } catch (_) {
    return false;
  }
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
