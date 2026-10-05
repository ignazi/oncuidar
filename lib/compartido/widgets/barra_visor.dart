import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';

/// Barra superior de los visores (PDF, Excel, video): el degradado dorado de las cabeceras.
PreferredSizeWidget barraVisor({
  required String titulo,
  required VoidCallback alVolver,
  Key? claveVolver,
  List<Widget> acciones = const [],
}) {
  final color = Paleta.sobreDorado;
  return AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    foregroundColor: color,
    iconTheme: IconThemeData(color: color),
    actionsIconTheme: IconThemeData(color: color),
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    // SizedBox.expand: la pila de AppBar no le da tamaño al fondo y, sin él, una
    // caja sin hijo mide cero y el degradado no se ve.
    flexibleSpace: SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: Paleta.degradadoCabecera),
      ),
    ),
    leading: IconButton(
      key: claveVolver,
      tooltip: 'Volver',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: alVolver,
    ),
    title: Text(
      titulo,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
    actions: acciones,
  );
}
