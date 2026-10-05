import 'package:flutter/material.dart';
import 'package:oncuidar/compartido/widgets/controles_zoom.dart';

/// Escala a la que acerca el doble toque.
const _escalaDobleToque = 2.0;

/// Contenido con zoom a gusto: pellizco, doble toque y botones de acercar/alejar.
///
/// Es el visor de todos los documentos (PDF, Excel e infografías), así el pellizco
/// y el arrastre se sienten igual en todos.
class VisorConZoom extends StatefulWidget {
  const VisorConZoom({
    super.key,
    required this.constructor,
    this.escalaInicial = _uno,
    this.escalaAjuste = _uno,
    this.zoomMinimo = _uno,
    this.zoomMaximo = 8,
    this.alineacion = Alignment.center,
    this.sobreOscuro = true,
    this.claveVisor,
    this.alMover,
    this.pie,
  });

  /// Dibuja el contenido según el tamaño de la zona visible.
  final Widget Function(Size zona) constructor;

  /// Escala con la que se abre.
  final double Function(Size zona) escalaInicial;

  /// Escala del botón «Ajustar».
  final double Function(Size zona) escalaAjuste;

  /// Escala mínima a la que se puede alejar.
  final double Function(Size zona) zoomMinimo;
  final double zoomMaximo;

  /// Dónde queda el contenido cuando es más chico que la zona (centrado o arriba).
  final Alignment alineacion;
  final bool sobreOscuro;
  final Key? claveVisor;

  /// Avisa cada vez que cambia el zoom o la posición.
  final void Function(Matrix4 matriz, Size zona)? alMover;

  /// Lo que va fijo sobre el contenido, abajo al centro (p. ej. el número de página).
  final Widget? pie;

  static double _uno(Size _) => 1;

  @override
  State<VisorConZoom> createState() => _EstadoVisorConZoom();
}

class _EstadoVisorConZoom extends State<VisorConZoom>
    with SingleTickerProviderStateMixin {
  TransformationController? _transformacion;
  late final AnimationController _animacion;
  Animation<Matrix4>? _animacionMatriz;
  Size _zona = Size.zero;
  Offset _puntoDobleToque = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animacion =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addListener(() {
          final matriz = _animacionMatriz;
          if (matriz != null) _transformacion?.value = matriz.value;
        });
  }

  @override
  void dispose() {
    _animacion.dispose();
    _transformacion?.removeListener(_avisarMovimiento);
    _transformacion?.dispose();
    super.dispose();
  }

  void _avisarMovimiento() {
    final t = _transformacion;
    if (t != null) widget.alMover?.call(t.value, _zona);
  }

  double get _minimo => widget.zoomMinimo(_zona);

  Matrix4 _matrizInicial() => escalaUniforme(widget.escalaInicial(_zona));

  void _irA(Matrix4 destino, {bool animar = false}) {
    final t = _transformacion;
    if (t == null) return;
    _animacion.stop();
    if (!animar) {
      t.value = destino;
      return;
    }
    _animacionMatriz = Matrix4Tween(
      begin: t.value,
      end: destino,
    ).animate(CurvedAnimation(parent: _animacion, curve: Curves.easeOut));
    _animacion.forward(from: 0);
  }

  Matrix4 _zoomHacia(double factor, Offset centro) => zoomAlrededor(
    _transformacion!.value,
    factor,
    centro,
    minima: _minimo,
    maxima: widget.zoomMaximo,
  );

  void _acercar(double factor) =>
      _irA(_zoomHacia(factor, Offset(_zona.width / 2, _zona.height / 2)));

  void _ajustar() => _irA(escalaUniforme(widget.escalaAjuste(_zona)));

  /// Doble toque: acerca hacia el punto tocado o, si ya está cerca, vuelve al inicio.
  void _alDobleToque() {
    final escala = escalaDe(_transformacion!.value);
    if (escala < _escalaDobleToque * 0.7) {
      _irA(
        _zoomHacia(_escalaDobleToque / escala, _puntoDobleToque),
        animar: true,
      );
    } else {
      _irA(_matrizInicial(), animar: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        final zonaAnterior = _zona;
        _zona = restricciones.biggest;
        if (_transformacion == null) {
          _transformacion = TransformationController(_matrizInicial())
            ..addListener(_avisarMovimiento);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => mounted ? _avisarMovimiento() : null,
          );
        } else if (zonaAnterior.width != _zona.width &&
            zonaAnterior != Size.zero) {
          // Al girar el teléfono se vuelve a la escala inicial de la nueva zona.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => mounted ? _irA(_matrizInicial()) : null,
          );
        }
        final minimo = _minimo;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onDoubleTapDown: (d) => _puntoDobleToque = d.localPosition,
                onDoubleTap: _alDobleToque,
                child: InteractiveViewer(
                  key: widget.claveVisor,
                  transformationController: _transformacion,
                  constrained: false,
                  minScale: minimo,
                  maxScale: widget.zoomMaximo,
                  // El lienzo mide al menos lo que se ve al alejar al máximo. Si el
                  // contenido es más bajo que la pantalla (un PDF apaisado, una hoja
                  // con pocas filas), el zoom de Flutter forzaba una escala mínima
                  // para llenarla: el primer toque «saltaba» y no dejaba alejar.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: _zona.width / minimo,
                      minHeight: _zona.height / minimo,
                    ),
                    child: Align(
                      alignment: widget.alineacion,
                      widthFactor: 1,
                      heightFactor: 1,
                      child: widget.constructor(_zona),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: ControlesZoom(
                sobreOscuro: widget.sobreOscuro,
                alAcercar: () => _acercar(1.5),
                alAlejar: () => _acercar(1 / 1.5),
                alAjustar: _ajustar,
              ),
            ),
            if (widget.pie != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                child: Center(child: widget.pie),
              ),
          ],
        );
      },
    );
  }
}
