import 'package:oncuidar/caracteristicas/biblioteca/dominio/categorias.dart';
import 'package:oncuidar/caracteristicas/biblioteca/dominio/material_educativo.dart';

/// Grupo de materiales de un mismo tipo en la vista «Todos».
class SeccionBiblioteca {
  const SeccionBiblioteca({required this.titulo, required this.materiales});

  /// Nombre del filtro que agrupa la sección (Videos, Guías, Infografías u Otros).
  final String titulo;
  final List<MaterialEducativo> materiales;
}

/// Orden de las secciones; lo que no calza en ninguna va al final como «Otros».
const ordenSecciones = ['Videos', 'Guías', 'Infografías'];

/// Agrupa por tipo en orden fijo, conserva el orden interno y omite secciones vacías.
List<SeccionBiblioteca> agruparPorSeccion(List<MaterialEducativo> materiales) {
  final grupos = {
    for (final titulo in ordenSecciones) titulo: <MaterialEducativo>[],
  };
  final otros = <MaterialEducativo>[];
  for (final material in materiales) {
    final titulo = ordenSecciones.firstWhere(
      (filtro) => coincideFiltro(filtro, material.categoria),
      orElse: () => '',
    );
    (titulo.isEmpty ? otros : grupos[titulo]!).add(material);
  }
  return [
    for (final MapEntry(key: titulo, value: lista) in grupos.entries)
      if (lista.isNotEmpty)
        SeccionBiblioteca(titulo: titulo, materiales: lista),
    if (otros.isNotEmpty) SeccionBiblioteca(titulo: 'Otros', materiales: otros),
  ];
}
