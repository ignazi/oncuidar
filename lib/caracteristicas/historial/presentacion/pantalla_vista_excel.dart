import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/caracteristicas/historial/datos/exportador_excel.dart';
import 'package:oncuidar/caracteristicas/historial/datos/formato_exportacion.dart';
import 'package:oncuidar/caracteristicas/historial/dominio/orden_registros.dart';
import 'package:oncuidar/caracteristicas/pacientes/dominio/paciente.dart';
import 'package:oncuidar/caracteristicas/registro_clinico/dominio/registro_clinico.dart';
import 'package:oncuidar/compartido/widgets/accion_descargar.dart';
import 'package:oncuidar/compartido/widgets/controles_zoom.dart';
import 'package:oncuidar/nucleo/utilidades/formato_fecha.dart';

/// Lo que lleva el Excel exportado; con esto se dibuja la misma hoja sin salir de la app.
class DatosHojaExcel {
  const DatosHojaExcel({
    required this.registros,
    required this.paciente,
    required this.nombreCuidador,
    required this.fechaInicio,
    required this.fechaFin,
    required this.generadoEn,
  });

  final List<RegistroClinico> registros;
  final Paciente? paciente;
  final String? nombreCuidador;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final DateTime generadoEn;
}

/// Abre la hoja de Excel dentro de la app (por encima de la barra inferior).
Future<void> abrirVistaExcel(
  BuildContext context, {
  required DatosHojaExcel datos,
  VoidCallback? alCompartir,
  Future<bool> Function()? alDescargar,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => PantallaVistaExcel(
        datos: datos,
        alCompartir: alCompartir,
        alDescargar: alDescargar,
      ),
    ),
  );
}

// Colores de la hoja: son los del archivo Excel, iguales en modo claro y oscuro.
const _dorado = Color(0xFFE8A820);
const _doradoEncabezado = Color(0xFFC47E10);
const _doradoTexto = Color(0xFFC08808);
const _doradoClaro = Color(0xFFFFF4D0);
const _crema = Color(0xFFFFF9E8);
const _texto = Color(0xFF2C1A00);
const _textoSuave = Color(0xFF6B5330);
const _linea = Color(0xFFE8DCC0);

/// Píxeles por carácter de ancho de columna del Excel.
const _pxPorCaracter = 7.2;

/// Zoom de la hoja: desde ver casi toda la tabla hasta leer cada celda grande.
const zoomMinimoHoja = 0.15;
const zoomMaximoHoja = 8.0;

/// Escala con la que se abre la hoja: legible, y con el resto a un deslizamiento.
const zoomInicialHoja = 0.6;

/// La hoja del historial como en Excel: ficha en dos columnas, resumen y tabla.
///
/// Se acerca y aleja con los dedos, con los botones o con doble toque, y se mueve
/// en ambas direcciones.
class PantallaVistaExcel extends StatefulWidget {
  const PantallaVistaExcel({
    super.key,
    required this.datos,
    this.alCompartir,
    this.alDescargar,
  });

  final DatosHojaExcel datos;
  final VoidCallback? alCompartir;
  final Future<bool> Function()? alDescargar;

  @override
  State<PantallaVistaExcel> createState() => _PantallaVistaExcelState();
}

class _PantallaVistaExcelState extends State<PantallaVistaExcel> {
  /// Ancho de la hoja más el margen que la rodea.
  static final _anchoContenido = _Hoja.anchoTotal + 32;

  final _transformacion = TransformationController(
    escalaUniforme(zoomInicialHoja),
  );
  Size _zona = Size.zero;
  Offset _puntoDobleToque = Offset.zero;

  @override
  void dispose() {
    _transformacion.dispose();
    super.dispose();
  }

  void _acercar(double factor, [Offset? centro]) {
    _transformacion.value = zoomAlrededor(
      _transformacion.value,
      factor,
      centro ?? Offset(_zona.width / 2, _zona.height / 2),
      minima: zoomMinimoHoja,
      maxima: zoomMaximoHoja,
    );
  }

  /// Deja toda la hoja a lo ancho de la pantalla.
  void _ajustarAlAncho() {
    final escala = (_zona.width / _anchoContenido).clamp(
      zoomMinimoHoja,
      zoomMaximoHoja,
    );
    _transformacion.value = escalaUniforme(escala);
  }

  /// Doble toque: acerca hacia el punto tocado o, si ya está cerca, vuelve a ajustar.
  void _alDobleToque() {
    final escala = escalaDe(_transformacion.value);
    if (escala >= 1.2) {
      _ajustarAlAncho();
    } else {
      _acercar(1.0 / escala, _puntoDobleToque);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EEE3),
      appBar: AppBar(
        leading: IconButton(
          key: const Key('cerrarVistaExcel'),
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Historial en Excel',
          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (widget.alDescargar != null)
            IconButton(
              key: const Key('descargarVistaExcel'),
              tooltip: 'Descargar',
              icon: const Icon(Icons.download_rounded),
              onPressed: () => descargarConAviso(context, widget.alDescargar!),
            ),
          if (widget.alCompartir != null)
            IconButton(
              key: const Key('compartirVistaExcel'),
              tooltip: 'Compartir',
              icon: const Icon(Icons.share_rounded),
              onPressed: widget.alCompartir,
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, restricciones) {
          _zona = restricciones.biggest;
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onDoubleTapDown: (d) => _puntoDobleToque = d.localPosition,
                  onDoubleTap: _alDobleToque,
                  child: InteractiveViewer(
                    key: const Key('zoomVistaExcel'),
                    transformationController: _transformacion,
                    constrained: false,
                    minScale: zoomMinimoHoja,
                    maxScale: zoomMaximoHoja,
                    // Margen amplio: se puede mover la hoja aunque quede pequeña.
                    boundaryMargin: const EdgeInsets.all(120),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _Hoja(datos: widget.datos),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                child: ControlesZoom(
                  sobreOscuro: false,
                  alAcercar: () => _acercar(1.5),
                  alAlejar: () => _acercar(1 / 1.5),
                  alAjustar: _ajustarAlAncho,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Hoja extends StatelessWidget {
  const _Hoja({required this.datos});

  final DatosHojaExcel datos;

  /// Ancho total de la hoja en píxeles.
  static double get anchoTotal => _ancho(0, 9);

  static double _ancho(int desde, int hasta) {
    var total = 0.0;
    for (var i = desde; i <= hasta; i++) {
      total += anchosColumnasExcel[i] * _pxPorCaracter;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final anchoIzquierda = _ancho(0, 4);
    final izquierda = bloquesPacienteYCuidador(
      datos.paciente,
      datos.nombreCuidador,
    );
    final derecha = bloquesCentroYContacto(datos.paciente);
    final nombre = datos.paciente?.nombreCompleto.trim();

    return Container(
      key: const Key('hojaExcel'),
      width: _ancho(0, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _linea),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            color: _dorado,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            child: Text(
              'HISTORIAL ONCUIDAR',
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: Text(
              [
                if (nombre != null && nombre.isNotEmpty) 'Paciente: $nombre',
                'Generado: ${fechacorta(datos.generadoEn)} '
                    '${hora12(datos.generadoEn)}',
              ].join('   ·   '),
              style: GoogleFonts.nunito(fontSize: 12, color: _textoSuave),
            ),
          ),
          for (
            var i = 0;
            i <
                (izquierda.length > derecha.length
                    ? izquierda.length
                    : derecha.length);
            i++
          )
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: anchoIzquierda,
                    child: i < izquierda.length
                        ? _Bloque(
                            bloque: izquierda[i],
                            anchoEtiqueta:
                                anchosColumnasExcel[0] * _pxPorCaracter,
                          )
                        : null,
                  ),
                  // Expanded (no ancho fijo): el borde de la hoja resta 2 px.
                  Expanded(
                    child: i < derecha.length
                        ? _Bloque(
                            bloque: derecha[i],
                            anchoEtiqueta:
                                anchosColumnasExcel[5] * _pxPorCaracter,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          _Bloque(
            bloque: (
              titulo: 'RESUMEN',
              filas: <FilaInfo>[
                (
                  rotuloPeriodo(datos.fechaInicio, datos.fechaFin),
                  etiquetaPeriodo(datos.fechaInicio, datos.fechaFin),
                ),
                ('Registros', '${datos.registros.length}'),
              ],
            ),
            anchoEtiqueta: anchosColumnasExcel[0] * _pxPorCaracter,
          ),
          const SizedBox(height: 12),
          _Tabla(registros: datos.registros),
        ],
      ),
    );
  }
}

/// Un bloque de la ficha: banda con el título y una fila por dato.
class _Bloque extends StatelessWidget {
  const _Bloque({required this.bloque, required this.anchoEtiqueta});

  final BloqueInfo bloque;
  final double anchoEtiqueta;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: _doradoClaro,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            bloque.titulo,
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _doradoTexto,
            ),
          ),
        ),
        for (final (etiqueta, valor) in bloque.filas)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: anchoEtiqueta,
                  child: Text(
                    etiqueta,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _doradoTexto,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    valor,
                    style: GoogleFonts.nunito(fontSize: 12, color: _texto),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tabla de registros: encabezado dorado, filas alternadas y texto largo en varias líneas.
class _Tabla extends StatelessWidget {
  const _Tabla({required this.registros});

  final List<RegistroClinico> registros;

  static Color _colorEstado(String estado) => switch (estado) {
    'Normal' => const Color(0xFF168A63),
    'Alerta' => const Color(0xFFB77900),
    'Crítico' => const Color(0xFFD1103F),
    _ => _texto,
  };

  @override
  Widget build(BuildContext context) {
    final datos = [
      for (final r in ordenarCronologicamente(registros))
        celdasRegistro(r, vacio: '–'),
    ];

    Widget celda(
      String texto, {
      required int columna,
      Color? color,
      bool negrita = false,
      bool encabezado = false,
    }) {
      final esTexto = columna >= 8;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        alignment: esTexto && !encabezado
            ? Alignment.centerLeft
            : Alignment.center,
        child: Text(
          texto,
          textAlign: esTexto && !encabezado ? TextAlign.left : TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: negrita || encabezado
                ? FontWeight.w800
                : FontWeight.w500,
            color: encabezado ? Colors.white : (color ?? _texto),
          ),
        ),
      );
    }

    return Table(
      key: const Key('tablaExcel'),
      columnWidths: {
        for (var i = 0; i < anchosColumnasExcel.length; i++)
          i: FixedColumnWidth(anchosColumnasExcel[i] * _pxPorCaracter),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: const TableBorder(
        horizontalInside: BorderSide(color: _linea, width: 0.6),
        bottom: BorderSide(color: _linea, width: 0.6),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: _doradoEncabezado),
          children: [
            for (var i = 0; i < encabezadosRegistro.length; i++)
              celda(
                encabezadosRegistro[i].replaceAll('O2', 'O₂'),
                columna: i,
                encabezado: true,
              ),
          ],
        ),
        for (final (n, fila) in datos.indexed)
          TableRow(
            decoration: BoxDecoration(color: n.isOdd ? _crema : Colors.white),
            children: [
              for (var i = 0; i < fila.length; i++)
                celda(
                  fila[i],
                  columna: i,
                  negrita: i == 3,
                  color: i == 3 ? _colorEstado(fila[i]) : null,
                ),
            ],
          ),
      ],
    );
  }
}
