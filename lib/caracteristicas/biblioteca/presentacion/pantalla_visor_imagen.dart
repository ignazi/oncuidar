import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/proveedores_navegacion.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/acciones_material.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/proveedores_biblioteca.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/widgets/imagen_cacheada.dart';

/// Etiqueta del Hero que comparten la tarjeta y el visor.
String etiquetaHeroImagen(String idMaterial) => 'imagen-material-$idMaterial';

/// Abre el visor con un fundido; la tarjeta vuela hacia él si comparte el Hero.
Future<void> abrirVisorImagen(
  BuildContext context, {
  required String url,
  required String titulo,
  String? idMaterial,
}) {
  return Navigator.of(context).push(
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
class PantallaVisorImagen extends ConsumerStatefulWidget {
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
  ConsumerState<PantallaVisorImagen> createState() =>
      _PantallaVisorImagenState();
}

class _PantallaVisorImagenState extends ConsumerState<PantallaVisorImagen>
    with SingleTickerProviderStateMixin {
  final _transformacion = TransformationController();
  late final AnimationController _animacion;
  late final PantallaCompletaNotifier _notificadorPantallaCompleta;
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
    _notificadorPantallaCompleta = ref.read(pantallaCompletaProvider.notifier);
    // La barra inferior se oculta tras el primer cuadro: no se cambia estado durante el build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notificadorPantallaCompleta.fijar(true);
    });
  }

  @override
  void dispose() {
    final notificador = _notificadorPantallaCompleta;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        notificador.fijar(false);
      } catch (_) {}
    });
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
                maxScale: 5,
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
    final imagen = ImagenCacheada(
      url: widget.url,
      ajuste: BoxFit.contain,
      reemplazo: const _ImagenIndisponible(),
    );
    final id = widget.idMaterial;
    if (id == null) return imagen;
    return Hero(tag: etiquetaHeroImagen(id), child: imagen);
  }

  Widget _barraSuperior() {
    final id = widget.idMaterial;
    final esFavorito =
        id != null &&
        (ref.watch(idsFavoritosProvider).value?.contains(id) ?? false);
    final compartible = !widget.url.startsWith('assets/');
    return IgnorePointer(
      ignoring: !_mostrarBarra,
      child: AnimatedOpacity(
        key: const Key('barraVisorImagen'),
        opacity: _mostrarBarra ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 4,
            left: 4,
            right: 4,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.75),
                Colors.black.withValues(alpha: 0),
              ],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                key: const Key('cerrarVisorImagen'),
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(
                  widget.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (id != null)
                IconButton(
                  key: const Key('favoritoVisorImagen'),
                  tooltip: esFavorito
                      ? 'Quitar de favoritos'
                      : 'Guardar en favoritos',
                  onPressed: () =>
                      unawaited(alternarFavoritoMaterial(ref, context, id)),
                  icon: Icon(
                    esFavorito ? Icons.bookmark : Icons.bookmark_border,
                    color: esFavorito ? Paleta.doradoMedio : Colors.white,
                  ),
                ),
              if (compartible)
                IconButton(
                  key: const Key('compartirVisorImagen'),
                  tooltip: 'Compartir',
                  onPressed: () => unawaited(
                    compartirImagenMaterial(
                      ref,
                      context,
                      widget.url,
                      widget.titulo,
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                ),
            ],
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
