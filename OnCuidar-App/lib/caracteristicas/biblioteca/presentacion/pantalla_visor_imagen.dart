import 'package:flutter/material.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/widgets/imagen_cacheada.dart';
import 'package:oncuidar/compartido/widgets/marco_visor.dart';
import 'package:oncuidar/compartido/widgets/visor_con_zoom.dart';

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

/// Infografía a pantalla completa: la misma pantalla que las guías en PDF (barra
/// dorada, zoom con los dedos, doble toque y botones de acercar y alejar).
class PantallaVisorImagen extends StatelessWidget {
  const PantallaVisorImagen({
    super.key,
    required this.url,
    required this.titulo,
    this.idMaterial,
  });

  final String url;
  final String titulo;

  /// Material al que pertenece.
  final String? idMaterial;

  @override
  Widget build(BuildContext context) {
    return MarcoVisor(
      fondo: const Color(0xFF0B0B0D),
      titulo: titulo,
      claveVolver: const Key('cerrarVisorImagen'),
      cuerpo: VisorConZoom(
        claveVisor: const Key('zoomVisorImagen'),
        constructor: (zona, factor) => SizedBox(
          key: const Key('areaVisorImagen'),
          width: zona.width * factor,
          height: zona.height * factor,
          child: ImagenCacheada(
            url: url,
            ajuste: BoxFit.contain,
            reemplazo: const _ImagenIndisponible(),
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
