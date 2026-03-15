// lib/presentation/scanner/scanner_screen.dart
// Écran Scanner — Viewfinder caméra + guidage visuel

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/router/route_names.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  late AnimationController _reticleController;
  late AnimationController _pulseController;
  late Animation<double> _reticlePulse;
  late Animation<double> _pulseOpacity;

  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();

    _reticleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _reticlePulse = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurveTween(curve: Curves.easeInOut).animate(_reticleController),
    );

    _pulseOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurveTween(curve: Curves.easeOut).animate(_pulseController),
    );
  }

  @override
  void dispose() {
    _reticleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _captureAndAnalyze() async {
    setState(() => _isAnalyzing = true);

    // Simulation analyse (sera remplacé par vrai ML Sprint 2)
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      context.goNamed(
        RouteNames.resultName,
        extra: {
          'disease': 'Mildiou',
          'plant': 'Tomate',
          'confidence': 0.92,
          'severity': 'danger',
          'advice': 'Appliquer du fongicide à base de cuivre. '
              'Éviter l\'arrosage par aspersion. '
              'Retirer les feuilles infectées.',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fond simulé (sera remplacé par CameraPreview) ─────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A2E20), Color(0xFF0D1A0F)],
              ),
            ),
            child: Center(
              child: Text(
                '📷  Caméra\n(Sprint 2)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.15),
                  fontSize: 18,
                ),
              ),
            ),
          ),

          // ── Overlay sombre autour du reticle ─────────────────
          _ScannerOverlay(reticleAnimation: _reticlePulse),

          // ── Interface controls ────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      // Bouton retour
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Flash toggle
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.flash_auto_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Message de guidage
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'Centrez la feuille dans le cadre',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(),

                // ── Bouton capture ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Column(
                    children: [
                      if (_isAnalyzing) ...[
                        // Indicateur d'analyse
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Analyse en cours…',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Bouton capture circulaire
                      _CaptureButton(
                        isAnalyzing: _isAnalyzing,
                        onPressed: _isAnalyzing ? null : _captureAndAnalyze,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overlay avec cadre de visée ───────────────────────────────────
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.reticleAnimation});
  final Animation<double> reticleAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: reticleAnimation,
      builder: (context, _) {
        return CustomPaint(
          painter: _OverlayPainter(
            reticleScale: reticleAnimation.value,
          ),
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({required this.reticleScale});
  final double reticleScale;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.60);

    final center = Offset(size.width / 2, size.height * 0.42);
    final reticleSize = size.width * 0.72 * reticleScale;
    final half = reticleSize / 2;

    final reticleRect = Rect.fromCenter(
      center: center,
      width: reticleSize,
      height: reticleSize * 0.78,
    );
    final reticleRRect = RRect.fromRectAndRadius(
      reticleRect,
      const Radius.circular(24),
    );

    // Zones sombres autour
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, center.dy - reticleSize * 0.78 / 2),
      overlayPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        center.dy + reticleSize * 0.78 / 2,
        size.width,
        size.height,
      ),
      overlayPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        center.dy - reticleSize * 0.78 / 2,
        center.dx - reticleSize / 2,
        reticleSize * 0.78,
      ),
      overlayPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx + reticleSize / 2,
        center.dy - reticleSize * 0.78 / 2,
        size.width,
        reticleSize * 0.78,
      ),
      overlayPaint,
    );

    // Bordure du reticle
    final borderPaint = Paint()
      ..color = AppColors.scannerReticle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(reticleRRect, borderPaint);

    // Coins accentués
    final cornerPaint = Paint()
      ..color = AppColors.scannerReticle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final cornerLen = 28.0;
    final r = 24.0;
    final l = reticleRect.left;
    final t = reticleRect.top;
    final ri = reticleRect.right;
    final bo = reticleRect.bottom;

    // Coin haut-gauche
    canvas.drawLine(Offset(l + r, t), Offset(l + r + cornerLen, t), cornerPaint);
    canvas.drawLine(Offset(l, t + r), Offset(l, t + r + cornerLen), cornerPaint);
    // Coin haut-droit
    canvas.drawLine(Offset(ri - r, t), Offset(ri - r - cornerLen, t), cornerPaint);
    canvas.drawLine(Offset(ri, t + r), Offset(ri, t + r + cornerLen), cornerPaint);
    // Coin bas-gauche
    canvas.drawLine(Offset(l + r, bo), Offset(l + r + cornerLen, bo), cornerPaint);
    canvas.drawLine(Offset(l, bo - r), Offset(l, bo - r - cornerLen), cornerPaint);
    // Coin bas-droit
    canvas.drawLine(Offset(ri - r, bo), Offset(ri - r - cornerLen, bo), cornerPaint);
    canvas.drawLine(Offset(ri, bo - r), Offset(ri, bo - r - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.reticleScale != reticleScale;
}

// ── Bouton de capture circulaire ──────────────────────────────────
class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.isAnalyzing,
    required this.onPressed,
  });

  final bool isAnalyzing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anneau externe
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 3,
              ),
            ),
          ),
          // Bouton interne
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAnalyzing
                  ? AppColors.primary.withOpacity(0.6)
                  : Colors.white,
            ),
            child: isAnalyzing
                ? const Icon(Icons.hourglass_top_rounded,
                    color: Colors.white, size: 28)
                : const Icon(Icons.camera_rounded,
                    color: AppColors.primary, size: 32),
          ),
        ],
      ),
    );
  }
}