import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Servicio de conectividad que expone un stream del estado de red.
///
/// Firestore ya tiene persistencia offline habilitada, así que los datos
/// se cachean automáticamente. Este servicio es para que la UI sepa
/// cuándo mostrar indicadores de "sin conexión".
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get isConnected => _controller.stream;

  bool _isConnected = true;
  bool get currentStatus => _isConnected;

  ConnectivityService() {
    // Verificar estado inicial
    _checkInitialStatus();

    // Escuchar cambios de conectividad
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (connected != _isConnected) {
        _isConnected = connected;
        _controller.add(connected);
      }
    });
  }

  Future<void> _checkInitialStatus() async {
    final results = await _connectivity.checkConnectivity();
    _isConnected = results.any((r) => r != ConnectivityResult.none);
    _controller.add(_isConnected);
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
