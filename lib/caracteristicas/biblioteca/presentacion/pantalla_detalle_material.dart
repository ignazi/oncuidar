import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/caracteristicas/biblioteca/dominio/categorias.dart';
import 'package:oncuidar/caracteristicas/biblioteca/dominio/material_educativo.dart';
import 'package:oncuidar/caracteristicas/biblioteca/dominio/parseo_contenido.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/acciones_material.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/proveedores_biblioteca.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/widgets/checklist_interactivo.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/widgets/dialogo_imagen_ampliable.dart';
import 'package:oncuidar/caracteristicas/biblioteca/presentacion/widgets/imagen_cacheada.dart';
import 'package:oncuidar/compartido/widgets/encabezado_gradiente.dart';

class PantallaDetalleMaterial extends ConsumerStatefulWidget {
  const PantallaDetalleMaterial({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PantallaDetalleMaterial> createState() =>
      _PantallaDetalleMaterialState();
}

class _PantallaDetalleMaterialState
    extends ConsumerState<PantallaDetalleMaterial> {
  MaterialEducativo? _material;
  bool _descargando = false;

  void _resolverMaterial(MaterialEducativo? material) {
    if (_material?.id != material?.id) {
      _material = material;
    }
  }

  Future<void> _abrirArchivo() async {
    final material = _material;
    if (material == null || material.fileUrl == null) return;
    setState(() => _descargando = true);
    try {
      await abrirArchivoMaterial(ref, context, material.fileUrl!);
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  void _mostrarImagen(final String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => DialogoImagenAmpliable(url: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contenidosAsync = ref.watch(contenidosEducativosProvider);
    final contenidos = contenidosAsync.value ?? const <MaterialEducativo>[];
    MaterialEducativo? material;
    for (final contenido in contenidos) {
      if (contenido.id == widget.id) {
        material = contenido;
        break;
      }
    }
    if (material == null) {
      final detalleAsync = ref.watch(contenidoDetalleProvider(widget.id));
      material = detalleAsync.value;
    }
    if (material != null) _resolverMaterial(material);
    final materialActual = material ?? _material;

    final favoritosAsync = ref.watch(idsFavoritosProvider);
    final esFavorito = favoritosAsync.value?.contains(widget.id) ?? false;

    return Scaffold(
      backgroundColor: Paleta.crema,
      body: Column(
        children: [
          EncabezadoGradiente(
            titulo: 'Material educativo',
            subtitulo: materialActual?.topic,
            reservaDerecha: 48,
            accionDerecha: GestureDetector(
              onTap: () =>
                  unawaited(alternarFavoritoMaterial(ref, context, widget.id)),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  esFavorito ? Icons.bookmark : Icons.bookmark_border,
                  color: esFavorito ? Paleta.doradoClaro : Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          Expanded(child: _cuerpo(materialActual)),
        ],
      ),
    );
  }

  Widget _cuerpo(MaterialEducativo? material) {
    if (material == null) {
      return const Center(
        child: Text(
          'Material no encontrado.',
          style: TextStyle(color: Paleta.textoSecundario),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (material.imageUrl != null && material.imageUrl!.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _mostrarImagen(material.imageUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _imagenCuerpo(material.imageUrl!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            material.title,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Paleta.textoPrincipal,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Paleta.doradoPrincipal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  etiquetaCategoria(material.category),
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Paleta.doradoOscuro,
                  ),
                ),
              ),
              if (material.topic.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    material.topic,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Paleta.textoSecundario,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (material.body.isNotEmpty) ...[
            if (material.esChecklist)
              ChecklistInteractivo(
                titulo: material.title,
                items: parsearItemsChecklist(material.body),
                textoIntro: textoInformativoChecklist(material.body),
              )
            else ...[
              const SizedBox(height: 16),
              ..._secciones(material.body),
            ],
          ],
          if (material.fileUrl != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _descargando ? null : _abrirArchivo,
                icon: _descargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  _descargando ? 'Descargando...' : 'Abrir archivo adjunto',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imagenCuerpo(String url) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: ImagenCacheada(
        url: url,
        ajuste: BoxFit.cover,
        reemplazo: _reemplazoImagen(),
      ),
    );
  }

  Widget _reemplazoImagen() {
    return Container(
      color: Paleta.fondoEntrada,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 48,
        color: Paleta.textoSecundario,
      ),
    );
  }

  List<Widget> _secciones(String body) {
    final bloques = parsearCuerpo(body);
    return [
      for (final bloque in bloques)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: bloque.esTitulo
              ? Text(
                  bloque.texto,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Paleta.doradoOscuro,
                  ),
                )
              : Text(
                  bloque.texto,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    height: 1.6,
                    color: Paleta.textoPrincipal,
                  ),
                ),
        ),
    ];
  }
}
