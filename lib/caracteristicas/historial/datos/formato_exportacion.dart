import 'package:oncuidar/caracteristicas/pacientes/dominio/paciente.dart';
import 'package:oncuidar/caracteristicas/registro_clinico/dominio/registro_clinico.dart';
import 'package:oncuidar/nucleo/utilidades/formato_fecha.dart';

/// Nombre legible del nivel de alerta.
String etiquetaEstado(NivelAlerta nivel) => switch (nivel) {
  NivelAlerta.normal => 'Normal',
  NivelAlerta.alerta => 'Alerta',
  NivelAlerta.critico => 'Crítico',
};

/// Nombre legible del tipo de registro.
String etiquetaTipoRegistro(String tipo) =>
    tipo == 'extra' ? 'Extra' : 'Programado';

/// Síntomas en una línea: «Fiebre (Moderada) 5/10, …».
String textoSintomas(List<EntradaSintoma> sintomas) {
  return sintomas
      .map(
        (s) =>
            '${s.nombre} (${EntradaSintoma.etiquetaPara(s.intensidad)}) ${s.intensidad}/10',
      )
      .join(', ');
}

/// Encabezados de la tabla de registros, en el orden de [celdasRegistro].
const encabezadosRegistro = [
  'Fecha',
  'Hora',
  'Tipo',
  'Estado',
  'Temp.',
  'F.C.',
  'Sat. O2',
  'F.R.',
  'Síntomas',
  'Observaciones',
];

/// Celdas de la tabla de registros; `vacio` reemplaza los datos ausentes.
List<String> celdasRegistro(RegistroClinico rec, {required String vacio}) {
  final vs = rec.signosVitales;
  return [
    fechacorta(rec.fecha),
    hora12(rec.creadoEn),
    etiquetaTipoRegistro(rec.tipoRegistro),
    etiquetaEstado(rec.nivelAlerta),
    vs?.temperatura != null
        ? '${vs!.temperatura!.toStringAsFixed(1)}°C'
        : vacio,
    vs?.frecuenciaCardiaca != null ? '${vs!.frecuenciaCardiaca} lpm' : vacio,
    vs?.saturacionOxigeno != null ? '${vs!.saturacionOxigeno}%' : vacio,
    vs?.frecuenciaRespiratoria != null
        ? '${vs!.frecuenciaRespiratoria} rpm'
        : vacio,
    rec.sintomas.isEmpty ? vacio : textoSintomas(rec.sintomas),
    rec.observaciones?.isNotEmpty == true ? rec.observaciones! : vacio,
  ];
}

/// Rótulo del dato de fechas: «Día» si se filtró un solo día, «Período» si no.
String rotuloPeriodo(DateTime? inicio, DateTime? fin) =>
    _esUnSoloDia(inicio, fin) ? 'Día' : 'Período';

/// Lo que se filtró, dicho con claridad: el día, el rango o «todos».
String etiquetaPeriodo(DateTime? inicio, DateTime? fin) {
  if (inicio == null && fin == null) return 'Todos los registros';
  if (_esUnSoloDia(inicio, fin)) return fechalarga(inicio!);
  if (inicio == null) return 'Hasta el ${fechacorta(fin!)}';
  if (fin == null) return 'Desde el ${fechacorta(inicio)}';
  return 'Del ${fechacorta(inicio)} al ${fechacorta(fin)}';
}

/// El historial trata un inicio sin fin como «ese día»; un rango del mismo día también.
bool _esUnSoloDia(DateTime? inicio, DateTime? fin) {
  if (inicio == null) return false;
  return fin == null || mismoDia(inicio, fin);
}

/// Una línea «etiqueta: valor» de un bloque de datos.
typedef FilaInfo = (String etiqueta, String valor);

/// Un bloque de datos con su título (Paciente, Cuidador…).
typedef BloqueInfo = ({String titulo, List<FilaInfo> filas});

bool _hay(String? texto) => texto != null && texto.trim().isNotEmpty;

/// Columna izquierda de la ficha: paciente y, debajo, cuidador.
List<BloqueInfo> bloquesPacienteYCuidador(
  Paciente? paciente,
  String? nombreCuidador,
) {
  return [
    if (paciente != null)
      (
        titulo: 'PACIENTE',
        filas: <FilaInfo>[
          ('Nombre', paciente.nombreCompleto),
          if (paciente.edad != null) ('Edad', '${paciente.edad} años'),
          if (_hay(paciente.diagnostico))
            ('Diagnóstico', paciente.diagnostico!),
          if (_hay(paciente.tratamientoFase))
            ('Fase', paciente.tratamientoFase!),
        ],
      ),
    if (_hay(nombreCuidador))
      (
        titulo: 'CUIDADOR',
        filas: <FilaInfo>[('Nombre', nombreCuidador!.trim())],
      ),
  ];
}

/// Columna derecha de la ficha: centro de salud y, debajo, contacto de emergencia.
List<BloqueInfo> bloquesCentroYContacto(Paciente? paciente) {
  if (paciente == null) return const [];
  return [
    if (_hay(paciente.centroSaludNombre))
      (
        titulo: 'CENTRO DE SALUD',
        filas: <FilaInfo>[
          ('Nombre', paciente.centroSaludNombre!),
          if (_hay(paciente.centroSaludDireccion))
            ('Dirección', paciente.centroSaludDireccion!),
          if (_hay(paciente.centroSaludTelefono))
            ('Teléfono', paciente.centroSaludTelefono!),
        ],
      ),
    if (_hay(paciente.contactoEmergenciaNombre))
      (
        titulo: 'CONTACTO DE EMERGENCIA',
        filas: <FilaInfo>[
          ('Nombre', paciente.contactoEmergenciaNombre!),
          if (_hay(paciente.contactoEmergenciaTelefono))
            ('Teléfono', paciente.contactoEmergenciaTelefono!),
        ],
      ),
  ];
}

/// Cuántas líneas ocupa [texto] en una celda de [caracteresPorLinea] (mínimo 1).
int lineasNecesarias(String texto, int caracteresPorLinea) {
  if (texto.isEmpty) return 1;
  var lineas = 0;
  for (final parrafo in texto.split('\n')) {
    var actual = 0;
    var cuenta = 1;
    for (final palabra in parrafo.split(' ')) {
      final largo = palabra.length;
      if (actual == 0) {
        actual = largo;
      } else if (actual + 1 + largo <= caracteresPorLinea) {
        actual += 1 + largo;
      } else {
        cuenta++;
        actual = largo;
      }
      // Una palabra más larga que la celda se parte en varias líneas.
      while (actual > caracteresPorLinea) {
        cuenta++;
        actual -= caracteresPorLinea;
      }
    }
    lineas += cuenta;
  }
  return lineas;
}
