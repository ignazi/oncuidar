import 'package:timezone/timezone.dart' as tz;

/// Número de día de la semana de cada clave de repetición.
const diasPorSemana = {
  'lun': DateTime.monday,
  'mar': DateTime.tuesday,
  'mie': DateTime.wednesday,
  'jue': DateTime.thursday,
  'vie': DateTime.friday,
  'sab': DateTime.saturday,
  'dom': DateTime.sunday,
};

/// Próximo de los [dias] a la hora programada, siempre después de [ahora].
tz.TZDateTime proximaCoincidenciaSemanal(
  tz.TZDateTime ahora,
  DateTime horaProgramada,
  List<String> dias,
) {
  // Se parte de hoy: un recordatorio semanal antiguo no debe quedar en el pasado.
  final candidato = tz.TZDateTime(
    ahora.location,
    ahora.year,
    ahora.month,
    ahora.day,
    horaProgramada.hour,
    horaProgramada.minute,
  );
  final objetivos =
      (dias.map((d) => diasPorSemana[d]).toList()
            ..removeWhere((d) => d == null))
          .toSet();

  for (var i = 0; i <= 7; i++) {
    final prueba = candidato.add(Duration(days: i));
    if (objetivos.contains(prueba.weekday) && prueba.isAfter(ahora)) {
      return prueba;
    }
  }
  return candidato.add(const Duration(days: 1));
}

/// Próxima coincidencia del mismo día del mes (ajustado a los días del mes)
/// a la hora programada, siempre después de [ahora].
tz.TZDateTime proximaMensual(tz.TZDateTime ahora, DateTime horaProgramada) {
  var anio = ahora.year;
  var mes = ahora.month;
  for (var i = 0; i < 13; i++) {
    final diasEnMes = DateTime(anio, mes + 1, 0).day;
    final dia = horaProgramada.day > diasEnMes ? diasEnMes : horaProgramada.day;
    final candidato = tz.TZDateTime(
      ahora.location,
      anio,
      mes,
      dia,
      horaProgramada.hour,
      horaProgramada.minute,
    );
    if (candidato.isAfter(ahora)) return candidato;
    mes++;
    if (mes > 12) {
      mes = 1;
      anio++;
    }
  }
  return ahora.add(const Duration(days: 32));
}

/// Fecha de un aviso de una sola vez; si ya pasó, se corre a mañana.
tz.TZDateTime momentoUnaVez(tz.TZDateTime ahora, DateTime fechaHora) {
  final momento = tz.TZDateTime(
    ahora.location,
    fechaHora.year,
    fechaHora.month,
    fechaHora.day,
    fechaHora.hour,
    fechaHora.minute,
  );
  return momento.isBefore(ahora)
      ? momento.add(const Duration(days: 1))
      : momento;
}
