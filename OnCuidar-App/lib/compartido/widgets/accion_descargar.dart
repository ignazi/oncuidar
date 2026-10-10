import 'package:flutter/material.dart';

/// Ejecuta la descarga y avisa si se guardó o no; pensado para el botón de un visor.
Future<void> descargarConAviso(
  BuildContext context,
  Future<bool> Function() descargar,
) async {
  final aviso = ScaffoldMessenger.of(context);
  final guardado = await descargar();
  aviso.showSnackBar(
    SnackBar(
      content: Text(
        guardado
            ? 'Archivo guardado en tu teléfono'
            : 'No se guardó el archivo',
      ),
    ),
  );
}
