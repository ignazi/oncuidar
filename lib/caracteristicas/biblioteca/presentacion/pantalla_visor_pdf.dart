import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/compartido/widgets/accion_descargar.dart';
import 'package:oncuidar/compartido/widgets/controles_zoom.dart';
import 'package:oncuidar/compartido/widgets/marco_visor.dart';
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
    return MarcoVisor(
      fondo: const Color(0xFF0B0B0D),
      titulo: titulo,
      claveVolver: const Key('cerrarVisorPdf'),
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
      cuerpo: constructor != null
          ? constructor(ruta)
          : _DocumentoPdf(ruta: ruta),
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

/// Ancho máximo, en píxeles, al que se dibuja una página (cuida la memoria).
const _pixelesMaximos = 4096.0;

/// Documento real: cada página se dibuja como imagen y el conjunto se acerca con
/// los dedos igual que una infografía (pellizco, doble toque y botones).
///
/// Las páginas se dibujan a la resolución de la pantalla y, al acercar, las que
/// se ven se vuelven a dibujar a la resolución del zoom: nunca se ven pixeladas.
class _DocumentoPdf extends StatefulWidget {
  const _DocumentoPdf({required this.ruta});

  final String ruta;

  @override
  State<_DocumentoPdf> createState() => _DocumentoPdfState();
}

/// Una página dibujada y el ancho en píxeles al que se dibujó.
typedef _Dibujo = ({Uint8List bytes, double pixeles});

class _DocumentoPdfState extends State<_DocumentoPdf> {
  final _paginas = <_Dibujo>[];
  final _proporciones = <double>[];

  /// Páginas visibles redibujadas más nítidas para el zoom actual.
  final _nitidas = <int, _Dibujo>{};
  PdfDocument? _documento;
  int _total = 0;
  bool _error = false;
  bool _cargaIniciada = false;
  bool _cerrado = false;
  int _paginaActual = 1;
  double _ancho = 0;
  double _densidad = 2;

  /// Android solo deja abierta una página a la vez: los dibujos van en fila.
  Future<void> _fila = Future.value();

  @override
  void dispose() {
    _cerrado = true;
    final documento = _documento;
    if (documento != null) {
      unawaited(_fila.whenComplete(documento.close));
    }
    super.dispose();
  }

  Future<T> _enFila<T>(Future<T> Function() tarea) {
    final resultado = _fila.then((_) => tarea());
    _fila = resultado.then<void>((_) {}, onError: (_) {});
    return resultado;
  }

  Future<_Dibujo?> _dibujar(int numero, double pixeles) => _enFila(() async {
    final documento = _documento;
    if (documento == null || _cerrado) return null;
    final pagina = await documento.getPage(numero);
    try {
      final ancho = pixeles.clamp(400.0, _pixelesMaximos);
      final imagen = await pagina.render(
        width: ancho,
        height: ancho * pagina.height / pagina.width,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
        quality: 92,
      );
      return imagen == null ? null : (bytes: imagen.bytes, pixeles: ancho);
    } finally {
      await pagina.close();
    }
  });

  /// Dibuja todas las páginas a la resolución de la pantalla, una tras otra.
  Future<void> _cargar() async {
    try {
      final documento = await PdfDocument.openFile(widget.ruta);
      _documento = documento;
      if (_cerrado) {
        await documento.close();
        return;
      }
      setState(() => _total = documento.pagesCount);
      for (var i = 1; i <= documento.pagesCount; i++) {
        final proporcion = await _enFila(() async {
          final pagina = await documento.getPage(i);
          final p = pagina.height / pagina.width;
          await pagina.close();
          return p;
        });
        final dibujo = await _dibujar(i, _ancho * _densidad);
        if (_cerrado || !mounted) return;
        if (dibujo != null) {
          setState(() {
            _paginas.add(dibujo);
            _proporciones.add(proporcion);
          });
        }
      }
    } on Object {
      if (mounted) setState(() => _error = true);
    }
  }

  /// Alto del documento con el zoom ya dibujado [factor].
  double _altoDocumento(double factor) {
    var alto = 0.0;
    for (final p in _proporciones) {
      alto += _ancho * factor * p + _separacionPaginas;
    }
    return alto;
  }

  /// Número de página y redibujo nítido de las páginas que se ven.
  void _alMover(Matrix4 matriz, Size zona, double factor) {
    if (_proporciones.isEmpty || _ancho == 0) return;
    final estirado = escalaDe(matriz);
    final relleno = ((zona.height * factor - _altoDocumento(factor)) / 2).clamp(
      0.0,
      double.infinity,
    );
    final arriba = -matriz.getTranslation().y / estirado - relleno;
    final abajo = arriba + zona.height / estirado;
    final centro = (arriba + abajo) / 2;

    var acumulado = 0.0;
    var pagina = _proporciones.length;
    final visibles = <int>[];
    for (var i = 0; i < _proporciones.length; i++) {
      final inicio = acumulado;
      acumulado += _ancho * factor * _proporciones[i] + _separacionPaginas;
      if (acumulado > arriba && inicio < abajo) visibles.add(i);
      if (centro < acumulado && pagina == _proporciones.length) {
        pagina = i + 1;
      }
    }
    if (pagina != _paginaActual) setState(() => _paginaActual = pagina);

    // Solo cuando el zoom ya se asentó (sin estirado) se redibuja nítido.
    if ((estirado - 1).abs() < 0.001) _afinar(visibles, factor);
  }

  void _afinar(List<int> visibles, double factor) {
    final necesarios = _ancho * factor * _densidad;
    // Lo que ya no se ve vuelve a la resolución normal (libera memoria).
    _nitidas.removeWhere((i, _) => !visibles.contains(i));
    for (final i in visibles) {
      final actual = _nitidas[i] ?? _paginas[i];
      if (actual.pixeles >= _pixelesMaximos ||
          actual.pixeles >= necesarios * 0.9) {
        continue;
      }
      unawaited(
        _dibujar(i + 1, necesarios).then((dibujo) {
          if (dibujo != null && mounted && !_cerrado) {
            setState(() => _nitidas[i] = dibujo);
          }
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        _ancho = restricciones.maxWidth;
        _densidad = MediaQuery.of(context).devicePixelRatio;
        if (!_cargaIniciada) {
          _cargaIniciada = true;
          unawaited(_cargar());
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
          constructor: (_, factor) => SizedBox(
            width: _ancho * factor,
            child: Column(
              children: [
                for (var i = 0; i < _paginas.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == _paginas.length - 1 ? 0 : _separacionPaginas,
                    ),
                    child: Image.memory(
                      (_nitidas[i] ?? _paginas[i]).bytes,
                      width: _ancho * factor,
                      height: _ancho * factor * _proporciones[i],
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
