import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true mientras una pantalla ocupa toda la pantalla (p. ej. un video): oculta la barra inferior.
class PantallaCompletaNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void fijar(bool valor) => state = valor;
}

final pantallaCompletaProvider =
    NotifierProvider<PantallaCompletaNotifier, bool>(
      PantallaCompletaNotifier.new,
    );
