import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncuidar/caracteristicas/configuracion/dominio/escala_texto.dart';
import 'package:oncuidar/caracteristicas/configuracion/dominio/modo_tema.dart';
import 'package:shared_preferences/shared_preferences.dart';

const claveEscalaTexto = 'escala_texto';
const claveModoTema = 'modo_tema';

/// Preferencia de un valor guardada como texto en el dispositivo.
abstract class _PreferenciaNotifier<T> extends Notifier<T> {
  bool _elegidoEnSesion = false;

  String get clave;
  T get porDefecto;
  T leer(String? guardado);
  String escribir(T valor);

  @override
  T build() {
    unawaited(_cargar());
    return porDefecto;
  }

  Future<void> _cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = leer(prefs.getString(clave));
      // Lo que el cuidador eligió mientras se leía tiene prioridad.
      if (ref.mounted && !_elegidoEnSesion) state = guardado;
    } catch (_) {
      // Sin preferencias se usa el valor por defecto.
    }
  }

  Future<void> fijar(T valor) async {
    _elegidoEnSesion = true;
    state = valor;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(clave, escribir(valor));
    } catch (_) {
      // Si no se puede guardar, el cambio vale solo en esta sesión.
    }
  }
}

/// Tamaño de texto elegido.
class EscalaTextoNotifier extends _PreferenciaNotifier<EscalaTexto> {
  @override
  String get clave => claveEscalaTexto;
  @override
  EscalaTexto get porDefecto => EscalaTexto.normal;
  @override
  EscalaTexto leer(String? guardado) => EscalaTexto.desdeNombre(guardado);
  @override
  String escribir(EscalaTexto valor) => valor.name;
}

final escalaTextoProvider = NotifierProvider<EscalaTextoNotifier, EscalaTexto>(
  EscalaTextoNotifier.new,
);

/// Apariencia elegida (automática, clara u oscura).
class ModoTemaNotifier extends _PreferenciaNotifier<ModoTema> {
  @override
  String get clave => claveModoTema;
  @override
  ModoTema get porDefecto => ModoTema.sistema;
  @override
  ModoTema leer(String? guardado) => ModoTema.desdeNombre(guardado);
  @override
  String escribir(ModoTema valor) => valor.name;
}

final modoTemaProvider = NotifierProvider<ModoTemaNotifier, ModoTema>(
  ModoTemaNotifier.new,
);
