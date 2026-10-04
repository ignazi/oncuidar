import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';
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
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => PantallaVisorPdf(
        ruta: ruta,
        titulo: titulo,
        alCompartir: alCompartir,
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
  });

  /// Ruta local del archivo ya descargado.
  final String ruta;
  final String titulo;
  final ConstructorDocumentoPdf? constructorDocumento;

  /// Si se da, la barra muestra el botón de compartir (p. ej. en las exportaciones).
  final VoidCallback? alCompartir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final constructor =
        constructorDocumento ?? ref.watch(constructorDocumentoPdfProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          key: const Key('cerrarVisorPdf'),
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
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

/// Documento real con pdfx: zoom con los dedos, desplazamiento vertical y número de página.
class _DocumentoPdf extends StatefulWidget {
  const _DocumentoPdf({required this.ruta});

  final String ruta;

  @override
  State<_DocumentoPdf> createState() => _DocumentoPdfState();
}

class _DocumentoPdfState extends State<_DocumentoPdf> {
  late final PdfControllerPinch _controlador = PdfControllerPinch(
    document: PdfDocument.openFile(widget.ruta),
  );

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: PdfViewPinch(
            controller: _controlador,
            // Más zoom del que se lee con comodidad solo gasta memoria y tiempo
            // de dibujo: 4x basta para ver el detalle en un teléfono.
            maxScale: 4,
            backgroundDecoration: const BoxDecoration(color: Color(0xFF0B0B0D)),
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              // El cambio de la vista previa a la página nítida es breve, no un fundido lento.
              options: const DefaultBuilderOptions(
                loaderSwitchDuration: Duration(milliseconds: 120),
              ),
              documentLoaderBuilder: (_) => Center(
                child: CircularProgressIndicator(color: Paleta.doradoMedio),
              ),
              pageLoaderBuilder: (_) => Center(
                child: CircularProgressIndicator(color: Paleta.doradoMedio),
              ),
              errorBuilder: (_, _) => Center(
                child: Text(
                  'No se pudo mostrar el PDF.',
                  style: GoogleFonts.nunito(fontSize: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          child: Center(
            child: PdfPageNumber(
              controller: _controlador,
              builder: (_, estado, pagina, total) =>
                  estado == PdfLoadingState.success && total != null
                  ? IndicadorPaginaPdf(pagina: pagina, total: total)
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
