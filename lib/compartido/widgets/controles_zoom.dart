import 'package:flutter/material.dart';

/// Escala de zoom de [matriz] (la longitud de su eje X).
///
/// No sirve `getMaxScaleOnAxis`: considera también el eje Z, que si se deja en 1
/// hace que cualquier zoom menor que 1 se lea como 1 y el alejar deje de funcionar.
double escalaDe(Matrix4 matriz) => matriz.getColumn(0).length;

/// Matriz de zoom uniforme en los tres ejes, sin desplazamiento.
Matrix4 escalaUniforme(double escala) =>
    Matrix4.diagonal3Values(escala, escala, escala);

/// Escala [matriz] por [factor] alrededor de [centro] (coordenadas del visor).
///
/// La escala resultante se limita a [minima]–[maxima]; la posición del punto
/// [centro] no se mueve, así el zoom se siente anclado a lo que se mira.
Matrix4 zoomAlrededor(
  Matrix4 matriz,
  double factor,
  Offset centro, {
  required double minima,
  required double maxima,
}) {
  final actual = escalaDe(matriz);
  final nueva = (actual * factor).clamp(minima, maxima);
  final relativo = nueva / actual;
  final alrededor =
      Matrix4.translationValues(centro.dx, centro.dy, 0) *
      Matrix4.diagonal3Values(relativo, relativo, relativo) *
      Matrix4.translationValues(-centro.dx, -centro.dy, 0);
  return alrededor * matriz;
}

/// Botones para acercar, alejar y ajustar al ancho, para visores con zoom.
///
/// Dan una forma de controlar el zoom que no depende de acertar con el pellizco.
class ControlesZoom extends StatelessWidget {
  const ControlesZoom({
    super.key,
    required this.alAcercar,
    required this.alAlejar,
    required this.alAjustar,
    this.sobreOscuro = true,
  });

  final VoidCallback alAcercar;
  final VoidCallback alAlejar;
  final VoidCallback alAjustar;

  /// Colores para un fondo oscuro (PDF) o claro (hoja de Excel).
  final bool sobreOscuro;

  @override
  Widget build(BuildContext context) {
    final fondo = sobreOscuro
        ? Colors.black.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.92);
    final icono = sobreOscuro ? Colors.white : const Color(0xFF2C1A00);
    Widget boton(
      Key clave,
      IconData datos,
      String ayuda,
      VoidCallback alTocar,
    ) => IconButton(
      key: clave,
      tooltip: ayuda,
      onPressed: alTocar,
      icon: Icon(datos, color: icono),
      visualDensity: VisualDensity.compact,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          boton(const Key('zoomMas'), Icons.add_rounded, 'Acercar', alAcercar),
          boton(
            const Key('zoomMenos'),
            Icons.remove_rounded,
            'Alejar',
            alAlejar,
          ),
          boton(
            const Key('zoomAjustar'),
            Icons.fit_screen_rounded,
            'Ajustar al ancho',
            alAjustar,
          ),
        ],
      ),
    );
  }
}
