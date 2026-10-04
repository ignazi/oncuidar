import 'package:flutter/material.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/app/tema/tipografia.dart';

/// Título de sección dorado con icono (Centro de salud, contactos, correos).
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.icono, this.texto, {super.key});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 17, color: Paleta.doradoOscuro),
        const SizedBox(width: 8),
        Text(
          texto,
          style: Tipografia.estilo(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Paleta.textoTerciario,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
