import 'package:flutter/material.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/app/tema/tipografia.dart';

class TarjetaSigno extends StatelessWidget {
  const TarjetaSigno({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.color,
    required this.hint,
    required this.unidad,
    required this.controlador,
    this.rango,
    this.decimal = false,
  });

  final String etiqueta;
  final IconData icono;
  final Color color;
  final String hint;
  final String unidad;
  final TextEditingController controlador;
  final String? rango;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Paleta.tarjeta,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Paleta.doradoOscuro.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icono, size: 15, color: color),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  etiqueta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Tipografia.estilo(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Paleta.textoSecundario,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextField(
                  controller: controlador,
                  keyboardType: decimal
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  style: Tipografia.estilo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Paleta.textoPrincipal,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hint,
                    hintStyle: Tipografia.estilo(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Paleta.textoAyuda,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              Text(
                unidad,
                style: Tipografia.estilo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          if (rango != null) ...[
            const SizedBox(height: 4),
            Text(
              'Rango: $rango $unidad',
              style: Tipografia.estilo(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Paleta.textoAyuda,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
