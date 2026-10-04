import 'package:flutter/material.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/app/tema/tipografia.dart';
import 'package:oncuidar/compartido/estilos.dart';

/// Campo de texto para observaciones adicionales del registro.
class CampoObservaciones extends StatelessWidget {
  const CampoObservaciones({super.key, required this.controlador});

  final TextEditingController controlador;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      maxLines: 2,
      keyboardType: TextInputType.multiline,
      style: Tipografia.estilo(
        fontSize: 14,
        height: 1.35,
        color: Paleta.textoPrincipal,
      ),
      decoration: entradaDorada(
        hintText:
            'Observaciones adicionales (opcional). Puedes guardar solo '
            'este campo si es lo disponible.',
        hintStyle: Tipografia.estilo(
          fontSize: 13,
          height: 1.3,
          color: Paleta.textoAyuda,
        ),
      ),
    );
  }
}
