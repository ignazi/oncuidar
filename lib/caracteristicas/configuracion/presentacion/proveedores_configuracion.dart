import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncuidar/caracteristicas/configuracion/dominio/escala_texto.dart';
import 'package:shared_preferences/shared_preferences.dart';

const claveEscalaTexto = 'escala_texto';

/// Tamaño de texto elegido; se guarda en el dispositivo.
class EscalaTextoNotifier extends Notifier<EscalaTexto> {
  @override
  EscalaTexto build() {
    unawaited(_cargar());
    return EscalaTexto.normal;
  }

  Future<void> _cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardada = EscalaTexto.desdeNombre(
        prefs.getString(claveEscalaTexto),
      );
      if (ref.mounted) state = guardada;
    } catch (_) {
      // Sin preferencias la app usa el tamaño normal.
    }
  }

  Future<void> fijar(EscalaTexto escala) async {
    state = escala;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(claveEscalaTexto, escala.name);
    } catch (_) {
      // Si no se puede guardar, el cambio vale solo en esta sesión.
    }
  }
}

final escalaTextoProvider = NotifierProvider<EscalaTextoNotifier, EscalaTexto>(
  EscalaTextoNotifier.new,
);
