import 'package:flutter/material.dart';
import 'package:oncuidar/compartido/widgets/controles_zoom.dart';

/// Escala a la que acerca el doble toque.
const _escalaDobleToque = 2.0;

/// Contenido con zoom a gusto: pellizco, doble toque y botones de acercar/alejar.
///
/// Usa el `InteractiveViewer` estándar (el mismo del visor de infografías), así el
/// pellizco y el arrastre se comportan igual en PDF, Excel e imágenes.
class VisorConZoom extends StatefulWidget {
  const VisorConZoom({
    super.key,
    required this.hijo,
    required this.escalaInicial,
    required this.escalaAjuste,
    this.zoomMinimo = 1,
    this.zoomMaximo = 8,
    this.margen = EdgeInsets.zero,
    this.sobreOscuro = true,
    this.claveVisor,
    this.alMover,
    this.pie,
  });

  final Widget hijo;

  /// Escala con la que se abre (según el tamaño de la zona).
  final double Function(Size zona) escalaInicial;

  /// Escala del botón «Ajustar» (según el tamaño de la zona).
  final double Function(Size zona) escalaAjuste;

  final double zoomMinimo;
  final double zoomMaximo;
  final EdgeInsets margen;
  final bool sobreOscuro;
  final Key? claveVisor;

  /// Avisa cada vez que cambia el zoom o la posición.
  final void Function(Matrix4 matriz, Size zona)? alMover;

  /// Lo que va fijo sobre el contenido, abajo al centro (p. ej. el número de página).
  final Widget? pie;

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
    minima: widget.zoomMinimo,
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
                  minScale: widget.zoomMinimo,
                  maxScale: widget.zoomMaximo,
                  boundaryMargin: widget.margen,
                  child: widget.hijo,
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
