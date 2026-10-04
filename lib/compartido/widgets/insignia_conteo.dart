import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';

/// Número sobre la esquina de un botón del encabezado.
///
/// Tiene su propio fondo café y un aro del color del botón: se distingue del
/// degradado dorado y del botón, y se ve igual en modo claro y oscuro.
class InsigniaConteo extends StatelessWidget {
  const InsigniaConteo({super.key, required this.total});

  final int total;

  /// Fondo de la insignia: café con el que el blanco del número se lee bien.
  static const colorFondo = Color(0xFF8A5A05);

  /// Color del número.
  static const colorNumero = Colors.white;

  /// Posición sobre la esquina superior derecha del botón.
  static Widget enEsquina(int total, {Key? clave}) => Positioned(
    top: -11,
    right: -11,
    child: InsigniaConteo(key: clave, total: total),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(13),
        // El aro tiene el color del botón: separa la insignia del degradado.
        border: Border.all(color: Paleta.tarjeta, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        total > 99 ? '99+' : '$total',
        textScaler: TextScaler.noScaling,
        style: GoogleFonts.nunito(
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w900,
          color: colorNumero,
        ),
      ),
    );
  }
}
