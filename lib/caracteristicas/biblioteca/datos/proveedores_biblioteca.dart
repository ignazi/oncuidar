import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oncuidar/caracteristicas/biblioteca/datos/repositorio_biblioteca.dart';
import 'package:oncuidar/nucleo/proveedores.dart';

final repositorioBibliotecaProvider = Provider<RepositorioBiblioteca>((ref) {
  return RepositorioBiblioteca(ref.watch(baseDatosSeguraProvider));
});
