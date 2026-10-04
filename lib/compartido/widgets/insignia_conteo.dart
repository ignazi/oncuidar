import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';

/// Número sobre la esquina de un botón del encabezado.
///
/// El fondo es el color del degradado del encabezado, así parece un pedazo que le
/// falta al botón. El aro claro y la sombra la separan del degradado, y el número
/// va en café oscuro: se lee igual en modo claro y oscuro, porque el degradado
/// dorado es el mismo en ambos.
class InsigniaConteo extends StatelessWidget {
  const InsigniaConteo({super.key, required this.total});

  final int total;

  /// Color del número: café oscuro, el que mejor se lee sobre el dorado.
  static const colorNumero = Color(0xFF3B2400);

  /// Cuánto sobresale de la esquina del botón.
  static const sobresale = 8.0;

  /// Color del degradado de la cabecera donde queda un botón de la derecha.
  static Color colorFondo() {
    final colores = Paleta.degradadoCabecera.colors;
    return Color.lerp(colores[1], colores[2], 0.55)!;
  }

  /// Posición sobre la esquina superior derecha del botón.
  static Widget enEsquina(int total, {Key? clave}) => Positioned(
    top: -sobresale,
    right: -sobresale,
    child: InsigniaConteo(key: clave, total: total),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: colorFondo(),
        borderRadius: BorderRadius.circular(12),
        // Aro claro: separa la insignia del degradado y del botón.
        border: Border.all(color: Paleta.aroInsignia, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
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
