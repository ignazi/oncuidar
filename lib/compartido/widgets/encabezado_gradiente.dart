import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';

class EncabezadoGradiente extends StatelessWidget {
  const EncabezadoGradiente({
    super.key,
    required this.titulo,
    this.alto = 100,
    this.tamanoTitulo,
    this.mostrarRetroceso = false,
    this.alRetroceder,
    this.subtitulo,
    this.accionDerecha,
    this.logo,
    this.iconoRetroceso = Icons.home_rounded,
    this.tituloCentrado = false,
    this.alTocarLogo,
  });

  final String titulo;
  final String? subtitulo;
  final double alto;

  static const _profundidadOla = 12.0;

  final double? tamanoTitulo;
  final bool mostrarRetroceso;
  final VoidCallback? alRetroceder;

  final Widget? accionDerecha;
  final ImageProvider? logo;
  final IconData iconoRetroceso;
  final bool tituloCentrado;
  final VoidCallback? alTocarLogo;

  @override
  Widget build(BuildContext context) {
    final alturaBarraEstado = MediaQuery.of(context).padding.top;
    final lateral = mostrarRetroceso ? 48.0 : 20.0;

    return SizedBox(
      height: alturaBarraEstado + alto,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ClipPath(
                clipper: const _ClipperOla(profundidad: _profundidadOla),
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: Paleta.degradadoCabecera),
                ),
              ),
            ),
          ),
          Align(
            alignment: tituloCentrado
                ? Alignment.center
                : const Alignment(-1, -0.35),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                lateral,
                alturaBarraEstado + 4,
                // Deja sitio a la insignia que sobresale del botón de la derecha.
                accionDerecha == null ? lateral : 24,
                4,
              ),
              // Logo y acciones en la misma fila: quedan a la misma altura.
              child: accionDerecha == null
                  ? FittedBox(fit: BoxFit.scaleDown, child: _izquierda())
                  : Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _izquierda(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        accionDerecha!,
                      ],
                    ),
            ),
          ),
          if (mostrarRetroceso)
            Positioned(
              top: alturaBarraEstado + 4,
              left: 4,
              child: Tooltip(
                message: 'Volver al inicio',
                child: GestureDetector(
                  onTap: alRetroceder ?? () => Navigator.of(context).pop(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconoRetroceso,
                      color: Paleta.sobreDorado,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Logo (si hay) y título, sin las acciones de la derecha.
  Widget _izquierda() {
    if (logo == null) return IgnorePointer(child: _contenidoTitulo());
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (alTocarLogo != null)
          GestureDetector(
            onTap: alTocarLogo,
            behavior: HitTestBehavior.opaque,
            child: _logoRedondo(),
          )
        else
          IgnorePointer(child: _logoRedondo()),
        const SizedBox(width: 10),
        IgnorePointer(child: _contenidoTitulo()),
      ],
    );
  }

  Widget _logoRedondo() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Paleta.tarjeta,
        shape: BoxShape.circle,
        // En oscuro el aro es un dorado tenue: el claro se vería como borde negro.
        border: Border.all(
          color: Paleta.esOscura ? Paleta.bordeTarjeta : Paleta.doradoClaro,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Paleta.doradoOscuro.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Image(image: logo!, width: 28, height: 28, fit: BoxFit.contain),
    );
  }

  Widget _contenidoTitulo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          textAlign: tituloCentrado ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.nunito(
            color: Paleta.sobreDorado,
            fontSize: tamanoTitulo ?? 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.15,
          ),
        ),
        if (subtitulo != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitulo!,
              textAlign: tituloCentrado ? TextAlign.center : TextAlign.left,
              style: GoogleFonts.nunito(
                color: Paleta.sobreDorado.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}

class _ClipperOla extends CustomClipper<Path> {
  const _ClipperOla({required this.profundidad});
  final double profundidad;

  @override
  Path getClip(Size size) {
    final bordeOla = size.height - profundidad;
    final ola = Path()
      ..moveTo(0, bordeOla)
      ..cubicTo(
        size.width * 0.33,
        size.height,
        size.width * 0.66,
        size.height,
        size.width,
        bordeOla,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      ola,
    );
  }

  @override
  bool shouldReclip(covariant _ClipperOla oldClipper) =>
      oldClipper.profundidad != profundidad;
}

/// Pantalla con el encabezado dorado fijo arriba y el contenido desplazable debajo.
class PantallaConEncabezado extends StatelessWidget {
  const PantallaConEncabezado({
    super.key,
    required this.alRegresar,
    required this.encabezado,
    required this.contenido,
  });

  final VoidCallback alRegresar;
  final Widget encabezado;
  final Widget contenido;

  @override
  Widget build(BuildContext context) {
    final altoBarra = MediaQuery.of(context).padding.top;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) alRegresar();
      },
      child: Scaffold(
        backgroundColor: Paleta.crema,
        body: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, altoBarra + 100 + 20, 20, 24),
                child: contenido,
              ),
            ),
            Positioned(top: 0, left: 0, right: 0, child: encabezado),
          ],
        ),
      ),
    );
  }
}
