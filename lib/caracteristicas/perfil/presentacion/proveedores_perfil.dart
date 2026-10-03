import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncuidar/caracteristicas/perfil/datos/proveedores_perfil.dart';

/// Datos visibles del cuidador con los campos personales descifrados. El
/// nombre llega del documento del cuidador en Firestore (Auth no guarda el
/// displayName), por eso el saludo usa este provider en lugar de Auth.
final cuidadorProvider = StreamProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) {
  return ref.watch(repositorioCuidadorProvider).cuidadorEnTiempoReal();
});
