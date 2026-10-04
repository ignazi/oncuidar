class MensajeConversacion {
  const MensajeConversacion({
    required this.texto,
    required this.delUsuario,
    this.enviadoEn,
  });

  final String texto;
  final bool delUsuario;

  /// Momento del envío; null en mensajes guardados antes de existir este dato.
  final DateTime? enviadoEn;

  Map<String, dynamic> aMapa() => {
    'texto': texto,
    'delUsuario': delUsuario,
    if (enviadoEn != null) 'enviadoEn': enviadoEn!.toUtc().toIso8601String(),
  };

  factory MensajeConversacion.desdeMapa(Map<String, dynamic> mapa) {
    return MensajeConversacion(
      texto: (mapa['texto'] as String?) ?? '',
      delUsuario: (mapa['delUsuario'] as bool?) ?? false,
      enviadoEn: DateTime.tryParse(
        (mapa['enviadoEn'] as String?) ?? '',
      )?.toLocal(),
    );
  }
}

class Conversacion {
  const Conversacion({
    required this.id,
    required this.titulo,
    required this.ultimaActividad,
    required this.creadoEn,
    required this.mensajes,
  });

  final String id;
  final String titulo;
  final DateTime ultimaActividad;
  final DateTime creadoEn;
  final List<MensajeConversacion> mensajes;
}
