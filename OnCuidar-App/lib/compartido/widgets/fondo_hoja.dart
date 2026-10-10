import 'package:flutter/material.dart';
import 'package:oncuidar/app/tema/paleta.dart';

/// Fondo con esquinas superiores redondeadas para el contenido de una hoja inferior.
///
/// El color se lee en cada build: así la hoja abierta sigue el cambio de modo
/// claro/oscuro sin cerrarse (el `backgroundColor` de la hoja se fija al abrirla).
class FondoHoja extends StatelessWidget {
  const FondoHoja({
    super.key,
    required this.child,
    this.sobreTarjeta = false,
    this.radio = 20,
  });

  final Widget child;

  /// Usa el color de tarjeta en vez del fondo crema de la app.
  final bool sobreTarjeta;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: sobreTarjeta ? Paleta.tarjeta : Paleta.crema,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radio)),
      ),
      child: child,
    );
  }
}
