import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';

/// Pantalla de reproducción de video offline.
/// Abre en landscape forzado con controles completos: play/pause, skip ±10s,
/// barra de progreso con scrubbing, y ocultación automática de controles.
class VideoPlayerScreen extends StatefulWidget {
  final File videoFile;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.videoFile,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _hasError = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _enterLandscapeImmersive();
    _initController();
  }

  Future<void> _initController() async {
    try {
      final controller = VideoPlayerController.file(widget.videoFile);
      _controller = controller;

      await controller.initialize();

      // Verificar que el widget sigue montado y que el controller no fue reemplazado
      if (!mounted || _controller != controller) {
        controller.dispose();
        return;
      }

      controller.addListener(_onVideoProgress);
      setState(() => _isInitialized = true);
      controller.play();
      _startControlsTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = e.toString();
        });
      }
    }
  }

  /// Bloquea landscape + oculta bars del sistema
  void _enterLandscapeImmersive() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Restaura orientación vertical + UI normal
  void _exitLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    // Primero pausar para evitar que el listener se dispare con estado disposed
    final c = _controller;
    if (c != null) {
      c.removeListener(_onVideoProgress);
      if (c.value.isPlaying) c.pause();
      c.dispose();
    }
    // Restaurar orientación después de un frame para evitar race condition
    // con la transición de ruta
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _exitLandscape();
    });
    super.dispose();
  }

  void _onVideoProgress() {
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !_isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    _startControlsTimer();
    setState(() {});
  }

  void _skipForward() {
    final c = _controller;
    if (c == null || !_isInitialized) return;
    final newPos = c.value.position + const Duration(seconds: 10);
    c.seekTo(newPos);
    _startControlsTimer();
  }

  void _skipBackward() {
    final c = _controller;
    if (c == null || !_isInitialized) return;
    final newPos = c.value.position - const Duration(seconds: 10);
    c.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
    _startControlsTimer();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  /// Oculta controles después de 4 segundos de inactividad
  void _startControlsTimer() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Restaurar orientación antes de navegar
        _exitLandscape();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video — ocupa toda la pantalla
              if (_hasError)
                _buildErrorView()
              else if (_isInitialized && _controller != null)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: AppColors.goldPrimary),
                ),

              // Controles superpuestos
              if (_showControls && _isInitialized && !_hasError)
                _buildControlsOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'No se pudo reproducir el video',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMsg,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: Colors.white54,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Volver',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();

    final position = c.value.position;
    final duration = c.value.duration;
    final isPlaying = c.value.isPlaying;

    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
            stops: const [0, 0.25, 0.75, 1],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Top bar: back + título ──
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () {
                      _exitLandscape();
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Centro: skip ◀◀  play/pause  ▶▶ skip ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSkipButton(
                  icon: Icons.replay_10_rounded,
                  onTap: _skipBackward,
                ),
                const SizedBox(width: 32),
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                _buildSkipButton(
                  icon: Icons.forward_10_rounded,
                  onTap: _skipForward,
                ),
              ],
            ),

            const Spacer(),

            // ── Bottom: barra de progreso + tiempos ──
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 20,
                right: 20,
              ),
              child: Column(
                children: [
                  VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.goldPrimary,
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white12,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkipButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}
