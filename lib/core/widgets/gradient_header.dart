import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Header reutilizable con gradiente dorado y ola convexa en la base.
///
/// Dos modos:
///   1. Brand header (showBackButton=false): Logo + "Oncuidar" + subtítulo
///   2. Detail header (showBackButton=true): Flecha atrás + título + opcional trailing
class GradientHeader extends StatelessWidget {
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final String? title;
  final Widget? trailing;
  final Widget? child;
  final double height;
  final double waveHeight;
  final bool centerChild;

  const GradientHeader({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
    this.title,
    this.trailing,
    this.child,
    this.height = 80,
    this.waveHeight = 18,
    this.centerChild = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: statusBarHeight + height + waveHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Fondo con gradiente (va edge-to-edge, detrás de status bar) ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.headerGradient,
              ),
            ),
          ),

          // ── Brillo sutil ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-0.8, -0.6),
                  end: const Alignment(0.8, 0.6),
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Contenido del header (empieza debajo de la status bar) ──
          Positioned(
            top: statusBarHeight,
            left: 0,
            right: 0,
            bottom: waveHeight,
            child: showBackButton
                ? _buildDetailHeader(context)
                : centerChild
                    ? Center(child: child)
                    : _buildBrandHeader(),
          ),

          // ── Ola convexa en la base ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, waveHeight),
              painter: WavePainter(color: AppColors.cream),
            ),
          ),
        ],
      ),
    );
  }

  /// Brand header: Título (custom u "Oncuidar") + subtítulo
  Widget _buildBrandHeader() {
    final displayTitle = title ?? 'Oncuidar';
    final showSubtitle = title == null;

    return Padding(
      // SafeArea ya maneja el notch,
      // usamos padding interno equivalente
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título — font-bold con sombra sutil
          Text(
            displayTitle,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.25,
              height: 1.2,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          // Subtítulo — color blanco 80%, tipografía chica
          if (showSubtitle)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Seguimiento y orientación para cuidadores',
                style: GoogleFonts.nunito(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 15,
                  height: 1.2,
                ),
              ),
            ),
          if (child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }

  /// Detail header: Flecha atrás + título + opcional trailing
  Widget _buildDetailHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBackPressed ?? () => GoRouter.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.home_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              if (title != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title!,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.25,
                      shadows: const [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              ?trailing,
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}

/// Pinta la ola convexa que conecta el gradiente con el fondo crema.
class WavePainter extends CustomPainter {
  final Color color;

  WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(
        size.width * 0.25,
        size.height,
        size.width * 0.75,
        size.height,
        size.width,
        0,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => false;
}
