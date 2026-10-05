import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/compartido/widgets/accion_descargar.dart';
import 'package:oncuidar/compartido/widgets/barra_visor.dart';
import 'package:oncuidar/compartido/widgets/controles_zoom.dart';
import 'package:oncuidar/compartido/widgets/visor_con_zoom.dart';
import 'package:pdfx/pdfx.dart';

/// Dibuja el documento de la ruta dada; en pruebas se reemplaza por uno falso.
typedef ConstructorDocumentoPdf = Widget Function(String ruta);

/// Constructor del documento que usan todos los visores; null = el real (pdfx).
/// Las pruebas lo sustituyen porque pdfx no se puede dibujar sin el teléfono.
final constructorDocumentoPdfProvider = Provider<ConstructorDocumentoPdf?>(
  (_) => null,
);

/// Abre el visor encima de toda la app, barra inferior incluida.
///
/// Se hace en el navegador raíz: así el visor ocupa la pantalla desde el primer
/// cuadro. Antes se ocultaba la barra inferior después de abrir y el documento
/// se redimensionaba y se volvía a dibujar, y eso se sentía lento.
Future<void> abrirVisorPdf(
  BuildContext context, {
  required String ruta,
  required String titulo,
  VoidCallback? alCompartir,
  Future<bool> Function()? alDescargar,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => PantallaVisorPdf(
        ruta: ruta,
        titulo: titulo,
        alCompartir: alCompartir,
        alDescargar: alDescargar,
      ),
    ),
  );
}

/// PDF a pantalla completa: barra con volver y título, zoom y desplazamiento vertical.
class PantallaVisorPdf extends ConsumerWidget {
  const PantallaVisorPdf({
    super.key,
    required this.ruta,
    required this.titulo,
    this.constructorDocumento,
    this.alCompartir,
    this.alDescargar,
  });

  /// Ruta local del archivo ya descargado.
  final String ruta;
  final String titulo;
  final ConstructorDocumentoPdf? constructorDocumento;

  /// Si se da, la barra muestra el botón de compartir (p. ej. en las exportaciones).
  final VoidCallback? alCompartir;

  /// Si se da, la barra muestra el botón de descargar al teléfono.
  final Future<bool> Function()? alDescargar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final constructor =
        constructorDocumento ?? ref.watch(constructorDocumentoPdfProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: barraVisor(
        titulo: titulo,
        claveVolver: const Key('cerrarVisorPdf'),
        alVolver: () => Navigator.of(context).maybePop(),
        acciones: [
          if (alDescargar != null)
            IconButton(
              key: const Key('descargarVisorPdf'),
              tooltip: 'Descargar',
              icon: const Icon(Icons.download_rounded),
              onPressed: () => descargarConAviso(context, alDescargar!),
            ),
          if (alCompartir != null)
            IconButton(
              key: const Key('compartirVisorPdf'),
              tooltip: 'Compartir',
              icon: const Icon(Icons.share_rounded),
              onPressed: alCompartir,
            ),
        ],
      ),
      body: constructor != null ? constructor(ruta) : _DocumentoPdf(ruta: ruta),
    );
  }
}

/// Píldora discreta con la página actual: «3 / 10».
class IndicadorPaginaPdf extends StatelessWidget {
  const IndicadorPaginaPdf({
    super.key,
    required this.pagina,
    required this.total,
  });

  final int pagina;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('indicadorPaginaPdf'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$pagina / $total',
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Zoom del documento: de la página a lo ancho hasta 6 veces.
const zoomMaximoPdf = 6.0;

/// Separación entre páginas.
const _separacionPaginas = 10.0;

/// Cuántas veces el ancho de la pantalla se dibuja cada página (nitidez al acercar).
const _nitidez = 2.5;

/// Documento real: cada página se dibuja como imagen y el conjunto se acerca con
/// los dedos igual que una infografía (pellizco, doble toque y botones).
class _DocumentoPdf extends StatefulWidget {
  const _DocumentoPdf({required this.ruta});

  final String ruta;

  @override
  State<_DocumentoPdf> createState() => _DocumentoPdfState();
}

class _DocumentoPdfState extends State<_DocumentoPdf> {
  final _paginas = <Uint8List>[];
  final _proporciones = <double>[];
  PdfDocument? _documento;
  int _total = 0;
  bool _error = false;
  bool _cargaIniciada = false;
  bool _cerrado = false;
  int _paginaActual = 1;
  double _ancho = 0;

  @override
  void dispose() {
    _cerrado = true;
    unawaited(_documento?.close());
    super.dispose();
  }

  /// Dibuja las páginas una tras otra (Android solo deja una abierta a la vez).
  Future<void> _cargar(double ancho) async {
    try {
      final documento = await PdfDocument.openFile(widget.ruta);
      _documento = documento;
      if (_cerrado) {
        await documento.close();
        return;
      }
      setState(() => _total = documento.pagesCount);
      final pixeles = (ancho * _nitidez).clamp(600.0, 2400.0);
      for (var i = 1; i <= documento.pagesCount; i++) {
        final pagina = await documento.getPage(i);
        final proporcion = pagina.height / pagina.width;
        final imagen = await pagina.render(
          width: pixeles,
          height: pixeles * proporcion,
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
          quality: 90,
        );
        await pagina.close();
        if (_cerrado || !mounted) return;
        if (imagen != null) {
          setState(() {
            _paginas.add(imagen.bytes);
            _proporciones.add(proporcion);
          });
        }
      }
    } on Object {
      if (mounted) setState(() => _error = true);
    }
  }

  /// Página que está en el centro de la pantalla, según el zoom y el desplazamiento.
  void _alMover(Matrix4 matriz, Size zona) {
    if (_proporciones.isEmpty || _ancho == 0) return;
    final escala = escalaDe(matriz);
    // Si el documento es más bajo que la pantalla, va centrado en ella.
    final relleno = ((zona.height - _altoDocumento) / 2).clamp(
      0.0,
      zona.height,
    );
    final yCentro =
        (-matriz.getTranslation().y + zona.height / 2) / escala - relleno;
    var acumulado = 0.0;
    var pagina = _proporciones.length;
    for (var i = 0; i < _proporciones.length; i++) {
      acumulado += _ancho * _proporciones[i] + _separacionPaginas;
      if (yCentro < acumulado) {
        pagina = i + 1;
        break;
      }
    }
    if (pagina != _paginaActual) setState(() => _paginaActual = pagina);
  }

  double get _altoDocumento {
    var alto = 0.0;
    for (final p in _proporciones) {
      alto += _ancho * p + _separacionPaginas;
    }
    return alto;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        _ancho = restricciones.maxWidth;
        if (!_cargaIniciada) {
          _cargaIniciada = true;
          unawaited(_cargar(_ancho));
        }
        if (_error) {
          return Center(
            child: Text(
              'No se pudo mostrar el PDF.',
              style: GoogleFonts.nunito(fontSize: 14, color: Colors.white),
            ),
          );
        }
        if (_paginas.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: Paleta.doradoMedio),
          );
        }
        return VisorConZoom(
          claveVisor: const Key('zoomVisorPdf'),
          zoomMaximo: zoomMaximoPdf,
          alMover: _alMover,
          pie: _total > 0
              ? IndicadorPaginaPdf(pagina: _paginaActual, total: _total)
              : null,
          constructor: (_) => SizedBox(
            width: _ancho,
            child: Column(
              children: [
                for (final (i, bytes) in _paginas.indexed)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == _paginas.length - 1 ? 0 : _separacionPaginas,
                    ),
                    child: Image.memory(
                      bytes,
                      width: _ancho,
                      height: _ancho * _proporciones[i],
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
