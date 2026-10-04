import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';

/// Número sobre la esquina de un botón del encabezado.
///
/// Lleva el color del degradado del encabezado, así parece un pedazo que le
/// falta al botón. El número va en café oscuro: se lee igual en modo claro y
/// oscuro, porque el degradado dorado es el mismo en ambos.
class InsigniaConteo extends StatelessWidget {
  const InsigniaConteo({super.key, required this.total});

  final int total;

  /// Color del degradado de la cabecera donde queda un botón de la derecha.
  static Color colorEncabezado() {
    final colores = Paleta.degradadoCabecera.colors;
    return Color.lerp(colores[1], colores[2], 0.55)!;
  }

  /// Posición sobre la esquina superior derecha del botón.
  static Widget enEsquina(int total, {Key? clave}) => Positioned(
    top: -10,
    right: -10,
    child: InsigniaConteo(key: clave, total: total),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: colorEncabezado(),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        total > 99 ? '99+' : '$total',
        textScaler: TextScaler.noScaling,
        style: GoogleFonts.nunito(
          fontSize: 13,
          height: 1,
          fontWeight: FontWeight.w900,
          color: coloresClaros.textoPrincipal,
        ),
      ),
    );
  }
}
