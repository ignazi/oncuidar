import 'package:flutter/material.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/widgets/imagen_cacheada.dart';
import 'package:oncuidar/compartido/widgets/barra_visor.dart';

/// Etiqueta del Hero que comparten la tarjeta y el visor.
String etiquetaHeroImagen(String idMaterial) => 'imagen-material-$idMaterial';

/// Abre el visor con un fundido, encima de toda la app (barra inferior incluida).
///
/// Va en el navegador raíz para que ocupe la pantalla desde el primer cuadro: antes
/// se ocultaba la barra inferior después de abrir y la imagen se redimensionaba y
/// «saltaba», lo que hacía que abriera raro.
Future<void> abrirVisorImagen(
  BuildContext context, {
  required String url,
  required String titulo,
  String? idMaterial,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) =>
          PantallaVisorImagen(url: url, titulo: titulo, idMaterial: idMaterial),
      transitionsBuilder: (_, animacion, _, hijo) =>
          FadeTransition(opacity: animacion, child: hijo),
    ),
  );
}

/// Escala a la que acerca el doble toque.
const escalaDobleToque = 2.5;

/// Infografía a pantalla completa con zoom, doble toque y barra que se oculta.
class PantallaVisorImagen extends StatefulWidget {
  const PantallaVisorImagen({
    super.key,
    required this.url,
    required this.titulo,
    this.idMaterial,
  });

  final String url;
  final String titulo;

  /// Material al que pertenece; habilita favorito y transición desde la tarjeta.
  final String? idMaterial;

  @override
  State<PantallaVisorImagen> createState() => _PantallaVisorImagenState();
}

class _PantallaVisorImagenState extends State<PantallaVisorImagen>
    with SingleTickerProviderStateMixin {
  final _transformacion = TransformationController();
  late final AnimationController _animacion;
  Animation<Matrix4>? _animacionMatriz;
  Offset _puntoDobleToque = Offset.zero;
  bool _mostrarBarra = true;

  @override
  void initState() {
    super.initState();
    _animacion =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addListener(() {
          final matriz = _animacionMatriz;
          if (matriz != null) _transformacion.value = matriz.value;
        });
  }

  @override
  void dispose() {
    _animacion.dispose();
    _transformacion.dispose();
    super.dispose();
  }

  void _alternarBarra() => setState(() => _mostrarBarra = !_mostrarBarra);

  /// Acerca en el punto tocado o vuelve al tamaño original.
  void _alternarZoom() {
    final escalaActual = _transformacion.value.getMaxScaleOnAxis();
    final Matrix4 destino;
    if (escalaActual > 1.01) {
      destino = Matrix4.identity();
    } else {
      final punto = _puntoDobleToque;
      destino = Matrix4.diagonal3Values(escalaDobleToque, escalaDobleToque, 1)
        ..setTranslationRaw(
          -punto.dx * (escalaDobleToque - 1),
          -punto.dy * (escalaDobleToque - 1),
          0,
        );
    }
    _animacionMatriz = Matrix4Tween(
      begin: _transformacion.value,
      end: destino,
    ).animate(CurvedAnimation(parent: _animacion, curve: Curves.easeOut));
    _animacion.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('areaVisorImagen'),
              onTap: _alternarBarra,
              onDoubleTapDown: (detalle) =>
                  _puntoDobleToque = detalle.localPosition,
              onDoubleTap: _alternarZoom,
              child: InteractiveViewer(
                transformationController: _transformacion,
                minScale: 1,
                maxScale: 8,
                child: Center(child: _imagen()),
              ),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _barraSuperior()),
        ],
      ),
    );
  }

  Widget _imagen() {
    return ImagenCacheada(
      url: widget.url,
      ajuste: BoxFit.contain,
      reemplazo: const _ImagenIndisponible(),
    );
  }

  Widget _barraSuperior() {
    return IgnorePointer(
      ignoring: !_mostrarBarra,
      child: AnimatedOpacity(
        key: const Key('barraVisorImagen'),
        opacity: _mostrarBarra ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          height: MediaQuery.of(context).padding.top + kToolbarHeight,
          child: barraVisor(
            titulo: widget.titulo,
            claveVolver: const Key('cerrarVisorImagen'),
            alVolver: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }
}

class _ImagenIndisponible extends StatelessWidget {
  const _ImagenIndisponible();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.white70, size: 40),
    );
  }
}
