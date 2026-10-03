import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/caracteristicas/biblioteca/dominio/categorias.dart';
import 'package:oncuidar/caracteristicas/biblioteca/dominio/material_educativo.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/pantalla_visor_imagen.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/widgets/imagen_cacheada.dart';

class TarjetaMaterial extends StatelessWidget {
  const TarjetaMaterial({
    super.key,
    required this.material,
    required this.esFavorito,
    required this.descargado,
    required this.alTocar,
    required this.alAlternarFavorito,
  });

  final MaterialEducativo material;
  final bool esFavorito;
  final bool descargado;
  final VoidCallback alTocar;
  final VoidCallback alAlternarFavorito;

  @override
  Widget build(BuildContext context) {
    if (!material.esVideo) {
      return _TarjetaDocumento(
        material: material,
        esFavorito: esFavorito,
        descargado: descargado,
        alTocar: alTocar,
        alAlternarFavorito: alAlternarFavorito,
      );
    }
    return _tarjetaVideo();
  }

  Widget _tarjetaVideo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Paleta.tarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Paleta.bordeTarjeta),
        boxShadow: [
          BoxShadow(
            color: Paleta.doradoOscuro.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            key: const Key('miniaturaTarjetaMaterial'),
            onTap: alTocar,
            behavior: HitTestBehavior.opaque,
            child: _miniatura(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _textos()),
                const SizedBox(width: 4),
                _iconoFavorito(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniatura() {
    final thumbnail = material.urlMiniatura;
    return SizedBox(
      height: 108,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnail != null && thumbnail.isNotEmpty)
            ImagenCacheada(
              url: thumbnail,
              ajuste: BoxFit.cover,
              reemplazo: _reemplazoMiniatura(),
            )
          else
            _reemplazoMiniatura(),
          if (material.esVideo)
            Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          Positioned(top: 8, left: 8, child: _insignia()),
          if (descargado && material.urlArchivo != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Paleta.doradoOscuro,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _reemplazoMiniatura() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Paleta.doradoClaro, Paleta.doradoMedio],
        ),
      ),
      child: Center(
        child: Icon(
          _iconoCategoria(),
          size: 34,
          color: Paleta.doradoOscuro.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Widget _insignia() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Paleta.doradoPrincipal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        etiquetaCategoria(material.categoria),
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _textos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          material.titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Paleta.textoPrincipal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          material.tema.isNotEmpty ? material.tema : material.categoria,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: Paleta.textoSecundario,
          ),
        ),
      ],
    );
  }

  Widget _iconoFavorito() {
    return GestureDetector(
      onTap: alAlternarFavorito,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Icon(
          esFavorito ? Icons.bookmark : Icons.bookmark_border,
          color: esFavorito ? Paleta.doradoPrincipal : Paleta.textoSecundario,
          size: 30,
        ),
      ),
    );
  }

  IconData _iconoCategoria() {
    switch (material.categoria.toLowerCase()) {
      case 'videos':
        return Icons.ondemand_video_rounded;
      case 'guías':
      case 'pdfs':
        return Icons.menu_book_rounded;
      case 'infografías':
        return Icons.image_rounded;
      default:
        return Icons.article_rounded;
    }
  }
}

/// Aspecto de cada tipo de documento: color, ícono y etiqueta.
({Color color, IconData icono}) estiloDocumento(String categoria) {
  if (categoria.toLowerCase() == 'infografías') {
    return (
      color: Paleta.categoriaInfografia,
      icono: Icons.insert_chart_outlined_rounded,
    );
  }
  // Guías y PDFs son lo mismo para el cuidador.
  return (color: Paleta.categoriaGuia, icono: Icons.menu_book_rounded);
}

/// Tarjeta horizontal para guías, PDFs e infografías.
class _TarjetaDocumento extends StatelessWidget {
  const _TarjetaDocumento({
    required this.material,
    required this.esFavorito,
    required this.descargado,
    required this.alTocar,
    required this.alAlternarFavorito,
  });

  final MaterialEducativo material;
  final bool esFavorito;
  final bool descargado;
  final VoidCallback alTocar;
  final VoidCallback alAlternarFavorito;

  @override
  Widget build(BuildContext context) {
    final estilo = estiloDocumento(material.categoria);
    return Container(
      key: const Key('tarjetaDocumento'),
      height: 168,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Paleta.tarjeta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Paleta.bordeTarjeta),
        boxShadow: [
          BoxShadow(
            color: Paleta.doradoOscuro.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, restricciones) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: restricciones.maxWidth * 0.38,
              child: GestureDetector(
                onTap: alTocar,
                behavior: HitTestBehavior.opaque,
                child: _panelTipo(estilo.color, estilo.icono),
              ),
            ),
            Expanded(child: _ladoDerecho(estilo.color, estilo.icono)),
          ],
        ),
      ),
    );
  }

  Widget _panelTipo(Color color, IconData icono) {
    return ColoredBox(
      color: color.withValues(alpha: 0.12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icono, size: 34, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            etiquetaCategoria(material.categoria),
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ladoDerecho(Color color, IconData icono) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                key: const Key('miniaturaTarjetaMaterial'),
                onTap: alTocar,
                behavior: HitTestBehavior.opaque,
                child: _imagen(color),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _textos()),
              _iconoFavorito(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagen(Color color) {
    final url = (material.urlMiniatura?.isNotEmpty ?? false)
        ? material.urlMiniatura!
        : material.urlImagen;
    final reemplazo = ColoredBox(
      color: color.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 30,
          color: color.withValues(alpha: 0.45),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            Hero(
              tag: etiquetaHeroImagen(material.id),
              child: ImagenCacheada(
                url: url,
                ajuste: BoxFit.cover,
                reemplazo: reemplazo,
              ),
            )
          else
            reemplazo,
          if (descargado && material.urlArchivo != null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _textos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          material.titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Paleta.textoPrincipal,
            height: 1.15,
          ),
        ),
        if (material.tema.isNotEmpty)
          Text(
            material.tema,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Paleta.textoSecundario,
            ),
          ),
      ],
    );
  }

  Widget _iconoFavorito() {
    return GestureDetector(
      onTap: alAlternarFavorito,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(
          esFavorito ? Icons.bookmark : Icons.bookmark_border,
          color: esFavorito ? Paleta.doradoPrincipal : Paleta.textoSecundario,
          size: 28,
        ),
      ),
    );
  }
}
