import 'package:shared_preferences/shared_preferences.dart';

/// Silencio de los avisos, guardado en el dispositivo (los avisos son locales).
///
/// Hay dos niveles independientes: el global (todos los pacientes) y el de cada
/// paciente. Un aviso suena solo si ninguno de los dos lo silencia, y activar uno
/// no toca el otro.
class SilencioAvisos {
  const SilencioAvisos._();

  static const claveGlobal = 'notificaciones_silenciadas';
  static const clavePacientes = 'pacientes_silenciados';

  /// ¿Están silenciados todos los avisos? Ante un fallo se asume que no.
  static Future<bool> global() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(claveGlobal) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> fijarGlobal(bool silenciar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(claveGlobal, silenciar);
    } catch (_) {
      // Si no se puede guardar, el silencio vale solo en esta sesión.
    }
  }

  /// Pacientes cuyos avisos están silenciados.
  static Future<Set<String>> pacientes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(clavePacientes) ?? const <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<bool> pacienteSilenciado(String idPaciente) async =>
      (await pacientes()).contains(idPaciente);

  static Future<void> fijarPaciente(String idPaciente, bool silenciar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = (prefs.getStringList(clavePacientes) ?? const <String>[])
          .toSet();
      if (silenciar ? !ids.add(idPaciente) : !ids.remove(idPaciente)) return;
      await prefs.setStringList(clavePacientes, ids.toList());
    } catch (_) {
      // Si no se puede guardar, el silencio vale solo en esta sesión.
    }
  }

  /// ¿Debe callarse el aviso de este paciente? (global o del paciente).
  static Future<bool> silenciado({String? idPaciente}) async {
    if (await global()) return true;
    if (idPaciente == null) return false;
    return pacienteSilenciado(idPaciente);
  }
}
