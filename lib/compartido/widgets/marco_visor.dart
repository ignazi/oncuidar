import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oncuidar/compartido/widgets/barra_visor.dart';

/// Pantalla de los visores (PDF, guías, Excel e infografías): barra dorada con
/// volver, sus acciones y un botón para girar a horizontal en pantalla completa,
/// como en los videos, para leer más cómodo.
class MarcoVisor extends StatefulWidget {
  const MarcoVisor({
    super.key,
    required this.titulo,
    required this.cuerpo,
    this.claveVolver,
    this.acciones = const [],
    this.fondo = const Color(0xFF0B0B0D),
  });

  final String titulo;
  final Widget cuerpo;
  final Key? claveVolver;
  final List<Widget> acciones;
  final Color fondo;

  @override
  State<MarcoVisor> createState() => _MarcoVisorState();
}

class _MarcoVisorState extends State<MarcoVisor> {
  bool _horizontal = false;

  @override
  void dispose() {
    if (_horizontal) _restaurarSistema();
    super.dispose();
  }

  /// La app es vertical y de borde a borde; así queda al salir del modo girado.
  static void _restaurarSistema() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _alternarGiro() {
    final horizontal = !_horizontal;
    if (horizontal) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _restaurarSistema();
    }
    setState(() => _horizontal = horizontal);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Atrás primero vuelve a vertical; un segundo atrás cierra el visor.
      canPop: !_horizontal,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _horizontal) _alternarGiro();
      },
      child: Scaffold(
        backgroundColor: widget.fondo,
        // Girado también se ve la barra: volver, el título y las acciones.
        appBar: barraVisor(
          titulo: widget.titulo,
          claveVolver: widget.claveVolver,
          alVolver: () => Navigator.of(context).maybePop(),
          acciones: [
            // Orden: girar, descargar, compartir.
            IconButton(
              key: const Key('girarVisor'),
              tooltip: _horizontal
                  ? 'Volver a vertical'
                  : 'Girar a pantalla completa',
              icon: Icon(
                _horizontal
                    ? Icons.screen_lock_portrait_rounded
                    : Icons.screen_rotation_rounded,
              ),
              onPressed: _alternarGiro,
            ),
            ...widget.acciones,
          ],
        ),
        body: widget.cuerpo,
      ),
    );
  }
}
