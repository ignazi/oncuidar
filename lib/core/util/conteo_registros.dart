import '../../modelos/registro_clinico.dart';
import 'formato_fecha.dart';

/// Registros programados del día: son los únicos que consumen el tope diario.
int contarProgramadosDelDia(
  Iterable<RegistroClinico> registros,
  DateTime dia,
) => registros
    .where((r) => r.tipoRegistro == 'programado' && mismoDia(r.fecha, dia))
    .length;

/// Registros extra del día: se informan aparte y no cuentan para el tope.
int contarExtrasDelDia(Iterable<RegistroClinico> registros, DateTime dia) =>
    registros
        .where((r) => r.tipoRegistro == 'extra' && mismoDia(r.fecha, dia))
        .length;
