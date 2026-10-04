import 'package:flutter/widgets.dart';

/// Marca para reconstruir todo lo que cuelga de [context].
///
/// Los colores de [Paleta] se leen en cada build, así que tras cambiar de modo
/// basta con reconstruir: incluso los widgets `const` vuelven a leerlos.
void repintarArbol(BuildContext context) {
  void repintar(Element elemento) {
    elemento.markNeedsBuild();
    elemento.visitChildren(repintar);
  }

  (context as Element).visitChildren(repintar);
}
