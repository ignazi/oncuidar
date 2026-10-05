import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/caracteristicas/historial/datos/exportador_excel.dart';
import 'package:oncuidar/caracteristicas/historial/datos/formato_exportacion.dart';
import 'package:oncuidar/caracteristicas/historial/dominio/orden_registros.dart';
import 'package:oncuidar/caracteristicas/pacientes/dominio/paciente.dart';
import 'package:oncuidar/caracteristicas/registro_clinico/dominio/registro_clinico.dart';
import 'package:oncuidar/compartido/widgets/accion_descargar.dart';
import 'package:oncuidar/compartido/widgets/barra_visor.dart';
import 'package:oncuidar/compartido/widgets/visor_con_zoom.dart';
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
const _lineaSuave = Color(0xFFE8DCC0);

// Cuadrícula y bordes como en Excel.
const _rejilla = Color(0xFFD4D4D4);
const _fondoRotulos = Color(0xFFF1F1F1);
const _textoRotulos = Color(0xFF555555);

/// Píxeles por carácter de ancho de columna del Excel.
const _pxPorCaracter = 8.0;

/// Ancho de la columna con los números de fila.
const _anchoNumeros = 38.0;

/// Alto de la fila con las letras de columna.
const _altoLetras = 24.0;

/// Alto de una línea de texto dentro de una celda.
const _altoLinea = 16.0;

/// Zoom de la hoja: desde ver casi toda la tabla hasta leer cada celda grande.
const zoomMinimoHoja = 0.15;
const zoomMaximoHoja = 8.0;

/// Escala con la que se abre la hoja: legible, y con el resto a un deslizamiento.
const zoomInicialHoja = 0.8;

/// Ancho total de la hoja (números de fila y las diez columnas).
final _anchoHoja =
    _anchoNumeros +
    anchosColumnasExcel.fold<double>(0, (a, b) => a + b * _pxPorCaracter);

/// Escala con la que toda la hoja cabe a lo ancho de la pantalla.
double _escalaAjuste(Size zona) =>
    (zona.width / _anchoHoja).clamp(zoomMinimoHoja, zoomMaximoHoja);

/// Una celda de la hoja, que puede abarcar varias columnas (como las combinadas de Excel).
class _Celda {
  const _Celda(
    this.desde,
    this.hasta,
    this.texto, {
    this.fondo,
    this.color = _texto,
    this.negrita = false,
    this.tamano = 12,
    this.centrado = false,
    this.ajustar = false,
    this.linea,
  });

  final int desde;
  final int hasta;
  final String texto;
  final Color? fondo;
  final Color color;
  final bool negrita;
  final double tamano;
  final bool centrado;

  /// Si el texto largo se reparte en varias líneas dentro de la celda.
  final bool ajustar;

  /// Borde inferior propio (las celdas con fondo no muestran la cuadrícula).
  final Color? linea;
}

class _Fila {
  const _Fila(this.alto, this.celdas, {this.clave});

  final double alto;
  final List<_Celda> celdas;
  final Key? clave;
}

double _anchoColumnas(int desde, int hasta) {
  var total = 0.0;
  for (var i = desde; i <= hasta; i++) {
    total += anchosColumnasExcel[i] * _pxPorCaracter;
  }
  return total;
}

/// Líneas que ocupa [texto] en las columnas [desde]–[hasta] (mínimo una).
int _lineas(String texto, int desde, int hasta) {
  final caracteres = ((_anchoColumnas(desde, hasta) - 14) / 6.8).floor();
  return lineasNecesarias(texto, math.max(4, caracteres));
}

/// Una fila de dato de la ficha: etiqueta en [desde] y valor hasta [hasta].
double _altoDato(String valor, int desde, int hasta) =>
    math.max(26, _lineas(valor, desde + 1, hasta) * _altoLinea + 10);

/// Pasa los datos a las filas de la hoja, igual que las escribe el archivo Excel.
List<_Fila> _construirFilas(DatosHojaExcel datos) {
  final filas = <_Fila>[];
  const ultima = 9;
  const ultimaIzquierda = 4;
  const hueco = _Fila(12, []);

  final nombre = datos.paciente?.nombreCompleto.trim();
  filas
    ..add(
      const _Fila(36, [
        _Celda(
          0,
          ultima,
          'HISTORIAL ONCUIDAR',
          fondo: _dorado,
          color: Colors.white,
          negrita: true,
          tamano: 17,
        ),
      ]),
    )
    ..add(
      _Fila(26, [
        _Celda(
          0,
          ultima,
          [
            if (nombre != null && nombre.isNotEmpty) 'Paciente: $nombre',
            'Generado: ${fechacorta(datos.generadoEn)} '
                '${hora12(datos.generadoEn)}',
          ].join('   ·   '),
          color: _textoSuave,
          tamano: 11,
        ),
      ]),
    )
    ..add(hueco);

  // Ficha en dos columnas, alineada por filas como en el archivo.
  final izquierda = bloquesPacienteYCuidador(
    datos.paciente,
    datos.nombreCuidador,
  );
  final derecha = bloquesCentroYContacto(datos.paciente);
  for (var i = 0; i < math.max(izquierda.length, derecha.length); i++) {
    final bloqueIzq = i < izquierda.length ? izquierda[i] : null;
    final bloqueDer = i < derecha.length ? derecha[i] : null;
    final cuantas = math.max(
      bloqueIzq == null ? 0 : bloqueIzq.filas.length + 1,
      bloqueDer == null ? 0 : bloqueDer.filas.length + 1,
    );
    for (var k = 0; k < cuantas; k++) {
      final celdas = <_Celda>[];
      var alto = 26.0;
      void lado(BloqueInfo? bloque, int desde, int hasta) {
        if (bloque == null || k > bloque.filas.length) return;
        if (k == 0) {
          celdas.add(
            _Celda(
              desde,
              hasta,
              bloque.titulo,
              fondo: _doradoClaro,
              color: _doradoTexto,
              negrita: true,
              tamano: 12.5,
            ),
          );
          return;
        }
        final (etiqueta, valor) = bloque.filas[k - 1];
        celdas
          ..add(
            _Celda(desde, desde, etiqueta, color: _doradoTexto, negrita: true),
          )
          ..add(_Celda(desde + 1, hasta, valor, ajustar: true));
        alto = math.max(alto, _altoDato(valor, desde, hasta));
      }

      lado(bloqueIzq, 0, ultimaIzquierda);
      lado(bloqueDer, ultimaIzquierda + 1, ultima);
      filas.add(_Fila(alto, celdas));
    }
    filas.add(hueco);
  }

  // Resumen: lo que se filtró y cuántos registros hay.
  filas.add(
    const _Fila(26, [
      _Celda(
        0,
        ultima,
        'RESUMEN',
        fondo: _doradoClaro,
        color: _doradoTexto,
        negrita: true,
        tamano: 12.5,
      ),
    ]),
  );
  for (final (etiqueta, valor) in <FilaInfo>[
    (
      rotuloPeriodo(datos.fechaInicio, datos.fechaFin),
      etiquetaPeriodo(datos.fechaInicio, datos.fechaFin),
    ),
    ('Registros', '${datos.registros.length}'),
  ]) {
    filas.add(
      _Fila(_altoDato(valor, 0, ultimaIzquierda), [
        _Celda(0, 0, etiqueta, color: _doradoTexto, negrita: true),
        _Celda(1, ultimaIzquierda, valor, ajustar: true),
      ]),
    );
  }
  filas.add(const _Fila(14, []));

  // Tabla de registros: encabezado dorado y filas alternadas.
  filas.add(
    _Fila(30, [
      for (var i = 0; i < encabezadosRegistro.length; i++)
        _Celda(
          i,
          i,
          encabezadosRegistro[i].replaceAll('O2', 'O₂'),
          fondo: _doradoEncabezado,
          color: Colors.white,
          negrita: true,
          centrado: true,
          ajustar: true,
          linea: _doradoEncabezado,
        ),
    ]),
  );
  for (final (n, registro) in ordenarCronologicamente(
    datos.registros,
  ).indexed) {
    final celdas = celdasRegistro(registro, vacio: '–');
    final lineas = math.max(_lineas(celdas[8], 8, 8), _lineas(celdas[9], 9, 9));
    filas.add(
      _Fila(
        math.max(28, lineas * _altoLinea + 12),
        clave: Key('filaRegistroExcel_$n'),
        [
          for (var i = 0; i < celdas.length; i++)
            _Celda(
              i,
              i,
              celdas[i],
              fondo: n.isOdd ? _crema : Colors.white,
              color: i == 3 ? _colorEstado(celdas[i]) : _texto,
              negrita: i == 3,
              centrado: i < 8,
              ajustar: true,
              linea: _lineaSuave,
            ),
        ],
      ),
    );
  }
  return filas;
}

Color _colorEstado(String estado) => switch (estado) {
  'Normal' => const Color(0xFF168A63),
  'Alerta' => const Color(0xFFB77900),
  'Crítico' => const Color(0xFFD1103F),
  _ => _texto,
};

/// La hoja del historial como en Excel: letras de columna, números de fila, cuadrícula
/// y pestaña «Historial». Se acerca y aleja con los dedos, con los botones o con
/// doble toque, y se mueve en ambas direcciones.
class PantallaVistaExcel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoRotulos,
      appBar: barraVisor(
        titulo: 'Historial en Excel',
        claveVolver: const Key('cerrarVistaExcel'),
        alVolver: () => Navigator.of(context).maybePop(),
        acciones: [
          if (alDescargar != null)
            IconButton(
              key: const Key('descargarVistaExcel'),
              tooltip: 'Descargar',
              icon: const Icon(Icons.download_rounded),
              onPressed: () => descargarConAviso(context, alDescargar!),
            ),
          if (alCompartir != null)
            IconButton(
              key: const Key('compartirVistaExcel'),
              tooltip: 'Compartir',
              icon: const Icon(Icons.share_rounded),
              onPressed: alCompartir,
            ),
        ],
      ),
      body: VisorConZoom(
        claveVisor: const Key('zoomVistaExcel'),
        sobreOscuro: false,
        // Lo más lejos: toda la hoja a lo ancho, como el botón «Ajustar».
        zoomMinimo: _escalaAjuste,
        zoomMaximo: zoomMaximoHoja,
        escalaInicial: (zona) =>
            zoomInicialHoja.clamp(_escalaAjuste(zona), zoomMaximoHoja),
        escalaAjuste: _escalaAjuste,
        alineacion: Alignment.topLeft,
        constructor: (_) => _Hoja(filas: _construirFilas(datos)),
      ),
      bottomNavigationBar: const _PestanaHoja(),
    );
  }
}

/// Pestaña «Historial» al pie, como la de las hojas de Excel.
class _PestanaHoja extends StatelessWidget {
  const _PestanaHoja();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(
        left: 12,
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: _fondoRotulos,
        border: Border(top: BorderSide(color: _rejilla)),
      ),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _dorado, width: 3)),
        ),
        child: Text(
          'Historial',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _texto,
          ),
        ),
      ),
    );
  }
}

class _Hoja extends StatelessWidget {
  const _Hoja({required this.filas});

  final List<_Fila> filas;

  static BorderSide get _borde => const BorderSide(color: _rejilla, width: 0.8);

  /// Letra de la columna: A, B, C…
  static String _letra(int i) => String.fromCharCode(65 + i);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('hojaExcel'),
      width: _anchoHoja,
      color: Colors.white,
      child: Column(
        key: const Key('tablaExcel'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _letras(),
          for (final (n, fila) in filas.indexed) _fila(n + 1, fila),
        ],
      ),
    );
  }

  Widget _rotulo(String texto, double ancho, [double? alto]) => Container(
    width: ancho,
    height: alto,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _fondoRotulos,
      border: Border(right: _borde, bottom: _borde),
    ),
    child: Text(
      texto,
      style: GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _textoRotulos,
      ),
    ),
  );

  Widget _letras() => Row(
    children: [
      _rotulo('', _anchoNumeros, _altoLetras),
      for (var i = 0; i < anchosColumnasExcel.length; i++)
        _rotulo(_letra(i), _anchoColumnas(i, i), _altoLetras),
    ],
  );

  Widget _fila(int numero, _Fila fila) {
    final porInicio = {for (final c in fila.celdas) c.desde: c};
    final partes = <Widget>[_rotulo('$numero', _anchoNumeros)];
    var columna = 0;
    while (columna < anchosColumnasExcel.length) {
      final celda = porInicio[columna];
      if (celda == null) {
        partes.add(
          Container(
            width: _anchoColumnas(columna, columna),
            constraints: BoxConstraints(minHeight: fila.alto),
            decoration: BoxDecoration(
              border: Border(right: _borde, bottom: _borde),
            ),
          ),
        );
        columna++;
      } else {
        partes.add(_celda(celda, fila.alto));
        columna = celda.hasta + 1;
      }
    }
    // El alto de la fila lo da la celda con más texto: ninguna palabra se corta.
    return IntrinsicHeight(
      key: fila.clave,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: partes,
      ),
    );
  }

  Widget _celda(_Celda c, double alto) {
    final texto = Text(
      c.texto,
      textAlign: c.centrado ? TextAlign.center : TextAlign.left,
      style: GoogleFonts.nunito(
        fontSize: c.tamano,
        fontWeight: c.negrita ? FontWeight.w800 : FontWeight.w500,
        color: c.color,
        height: _altoLinea / c.tamano,
      ),
    );
    return Container(
      width: _anchoColumnas(c.desde, c.hasta),
      constraints: BoxConstraints(minHeight: alto),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      alignment: c.centrado ? Alignment.center : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: c.fondo,
        // Con fondo no se ve la cuadrícula; solo la línea propia de la celda.
        border: c.fondo == null
            ? Border(right: _borde, bottom: _borde)
            : Border(
                bottom: BorderSide(color: c.linea ?? c.fondo!, width: 0.8),
              ),
      ),
      child: texto,
    );
  }
}
