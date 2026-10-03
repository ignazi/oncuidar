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
            '${s.name} (${EntradaSintoma.etiquetaPara(s.intensity)}) ${s.intensity}/10',
      )
      .join(', ');
}

/// Celdas de la tabla de registros; `vacio` reemplaza los datos ausentes.
List<String> celdasRegistro(RegistroClinico rec, {required String vacio}) {
  final vs = rec.signosVitales;
  return [
    fechacorta(rec.fecha),
    hora12(rec.creadoEn),
    etiquetaTipoRegistro(rec.tipoRegistro),
    etiquetaEstado(rec.nivelAlerta),
    vs?.temperature != null
        ? '${vs!.temperature!.toStringAsFixed(1)}°C'
        : vacio,
    vs?.heartRate != null ? '${vs!.heartRate} lpm' : vacio,
    vs?.oxygenSaturation != null ? '${vs!.oxygenSaturation}%' : vacio,
    vs?.respiratoryRate != null ? '${vs!.respiratoryRate} rpm' : vacio,
    textoSintomas(rec.sintomas),
    rec.observaciones?.isNotEmpty == true ? rec.observaciones! : vacio,
  ];
}
