// lib/presentation/scanner/scanner_screen.dart
// Scanner simplifié — capture unique OU galerie (1-3 photos)
// Inférence directe au tap sur ANALYSER, aucun timer, aucun frame

import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/router/route_names.dart';
import '../../core/services/tflite_loader.dart';
import '../../data/ml/ml_service.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {

  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _flashOn = false;
  bool _isAnalyzing = false;

  // Photos sélectionnées (1 à 3)
  final List<Uint8List> _selectedPhotos = [];

  // Mode actuel : viewfinder ou sélection galerie
  _ScanMode _mode = _ScanMode.viewfinder;

  late AnimationController _reticleController;
  late Animation<double> _reticle;

  @override
  void initState() {
    super.initState();
    _reticleController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _reticle = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _reticleController, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final ctrl = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      if (mounted) {
        setState(() {
          _cameraController = ctrl;
          _cameraReady = true;
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // ── Capture via caméra ─────────────────────────────────────────
  Future<void> _capturePhoto() async {
    if (!_cameraReady || _cameraController == null) return;
    if (_cameraController!.value.isTakingPicture) return;

    try {
      HapticFeedback.mediumImpact();
      final xFile = await _cameraController!.takePicture();
      final bytes = await xFile.readAsBytes();
      setState(() {
        _selectedPhotos.clear();
        _selectedPhotos.add(bytes);
        _mode = _ScanMode.preview;
      });
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  // ── Chargement depuis galerie (1 à 3 photos) ──────────────────
  Future<void> _pickFromGallery() async {
    if (_selectedPhotos.length >= 3) {
      _showMaxPhotosMessage();
      return;
    }
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();
      setState(() {
        _selectedPhotos.add(bytes);
        _mode = _ScanMode.preview;
      });
    } catch (e) {
      debugPrint('Gallery error: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
      if (_selectedPhotos.isEmpty) _mode = _ScanMode.viewfinder;
    });
  }

  void _showMaxPhotosMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maximum 3 photos')),
    );
  }

  // ── ANALYSER — inférence directe ─────────────────────────────
  Future<void> _analyze() async {
    if (_selectedPhotos.isEmpty || _isAnalyzing) return;

    final modelState = ref.read(tfliteLoaderProvider);
    if (modelState != ModelLoadState.ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modèle IA non disponible')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await MlService.instance.predictMultiple(_selectedPhotos);
      debugPrint('✅ Résultat : $result');
      debugPrint('   Tous les scores : ${result.allScores}');

      if (mounted) {
        context.goNamed(
          RouteNames.resultName,
          extra: {
            'disease':    result.label,
            'confidence': result.confidence,
            'severity':   result.severityKey,
            'allScores':  result.allScores,
            'advice':     _adviceForDisease(result.label),
            'photoCount': _selectedPhotos.length,
          },
        );
      }
    } catch (e) {
      debugPrint('Analysis error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    setState(() => _flashOn = !_flashOn);
    await _cameraController!.setFlashMode(
      _flashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  void _goBack() {
    _reticleController.stop();
    if (context.canPop()) context.pop();
    else context.goNamed(RouteNames.homeName);
  }

  String _adviceForDisease(String label) {
    const advice = {
      'Bacterienne': 'Appliquer un bactéricide à base de cuivre. Éviter l\'arrosage par aspersion. Retirer et brûler les parties infectées.',
      'Fongique':    'Traiter avec un fongicide adapté (cuivre ou soufre). Améliorer la ventilation. Éviter l\'humidité excessive sur le feuillage.',
      'Parasitaire': 'Appliquer un acaricide ou insecticide selon le parasite. Inspecter les plants voisins. Traiter en début de matinée.',
      'Virale':      'Pas de traitement curatif. Arracher et détruire les plants infectés. Lutter contre les insectes vecteurs.',
      'Saine':       'Votre plante est en bonne santé. Continuez votre routine d\'entretien.',
    };
    return advice[label] ?? 'Consulter un technicien agricole.';
  }

  @override
  void dispose() {
    _reticleController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _mode == _ScanMode.preview
          ? _buildPreviewMode()
          : _buildViewfinderMode(),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MODE VIEWFINDER — caméra live + boutons d'action
  // ══════════════════════════════════════════════════════════════

  Widget _buildViewfinderMode() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Caméra
        if (_cameraReady && _cameraController != null)
          CameraPreview(_cameraController!)
        else
          _buildCameraPlaceholder(),

        // Overlay reticle
        AnimatedBuilder(
          animation: _reticle,
          builder: (_, __) => CustomPaint(
            painter: _ReticlePainter(scale: _reticle.value),
          ),
        ),

        // UI controls
        SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _IconBtn(icon: Icons.arrow_back_rounded, onTap: _goBack),
                    const Spacer(),
                    _IconBtn(
                      icon: _flashOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      onTap: _toggleFlash,
                      active: _flashOn,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Consigne
              _GuidanceChip(text: 'Centrez la feuille et photographiez'),

              const Spacer(),

              // Boutons d'action en bas
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                child: Column(
                  children: [
                    // Bouton capture principal — grand et central
                    GestureDetector(
                      onTap: _capturePhoto,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Center(
                          child: Container(
                            width: 62,
                            height: 62,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Icon(
                              Icons.camera_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Bouton galerie — secondaire
                    GestureDetector(
                      onTap: _pickFromGallery,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Charger depuis la galerie',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      color: const Color(0xFF0D1A0F),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_rounded, color: Colors.white24, size: 56),
            SizedBox(height: 12),
            Text(
              'Initialisation caméra…',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MODE PREVIEW — aperçu photos + bouton ANALYSER
  // ══════════════════════════════════════════════════════════════

  Widget _buildPreviewMode() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedPhotos.clear();
                    _mode = _ScanMode.viewfinder;
                  }),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Photos sélectionnées',
                          style: AppTextStyles.titleMedium),
                      Text(
                        '${_selectedPhotos.length}/3 photo${_selectedPhotos.length > 1 ? "s" : ""}',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Grille photos
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPhotoGrid(),
            ),
          ),

          const SizedBox(height: 16),

          // Scores debug (à retirer en prod)
          // -- masqué --

          // Bouton ANALYSER
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              children: [
                // Bouton ajouter photo (si < 3)
                if (_selectedPhotos.length < 3) ...[
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate_rounded,
                              color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Ajouter une photo',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ANALYSER — bouton principal
                GestureDetector(
                  onTap: _isAnalyzing ? null : _analyze,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: _isAnalyzing
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF25C28A), Color(0xFF0F6E52)],
                            ),
                      color: _isAnalyzing ? AppColors.textTertiary : null,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _isAnalyzing
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: _isAnalyzing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 14),
                              Text('Analyse en cours…',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.biotech_rounded,
                                  color: Colors.white, size: 26),
                              const SizedBox(width: 12),
                              Text(
                                'ANALYSER',
                                style: AppTextStyles.buttonLarge.copyWith(
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    if (_selectedPhotos.length == 1) {
      // Une seule photo — plein écran
      return _PhotoCard(
        bytes: _selectedPhotos[0],
        onRemove: () => _removePhoto(0),
      );
    }

    // 2 ou 3 photos — grille
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _selectedPhotos.length,
      itemBuilder: (_, i) => _PhotoCard(
        bytes: _selectedPhotos[i],
        onRemove: () => _removePhoto(i),
        label: 'Photo ${i + 1}',
      ),
    );
  }
}

// ── Mode enum ─────────────────────────────────────────────────────
enum _ScanMode { viewfinder, preview }

// ── Widgets utilitaires ───────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withOpacity(0.8)
              : Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _GuidanceChip extends StatelessWidget {
  const _GuidanceChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.bytes,
    required this.onRemove,
    this.label,
  });
  final Uint8List bytes;
  final VoidCallback onRemove;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
        // Bouton supprimer
        Positioned(
          top: 8, right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
        // Label numéro
        if (label != null)
          Positioned(
            bottom: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label!,
                style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Reticle painter ───────────────────────────────────────────────
class _ReticlePainter extends CustomPainter {
  _ReticlePainter({required this.scale});
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withOpacity(0.55);
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final rw = size.width * 0.70 * scale;
    final rh = rw * 0.78;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: rw, height: rh);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, rect.top), overlay);
    canvas.drawRect(Rect.fromLTWH(0, rect.bottom, size.width, size.height - rect.bottom), overlay);
    canvas.drawRect(Rect.fromLTWH(0, rect.top, rect.left, rh), overlay);
    canvas.drawRect(Rect.fromLTWH(rect.right, rect.top, size.width - rect.right, rh), overlay);

    final border = Paint()
      ..color = AppColors.scannerReticle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)), border);

    final corner = Paint()
      ..color = AppColors.scannerReticle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cL = 24.0;
    const r = 20.0;
    // HG
    canvas.drawLine(Offset(rect.left + r, rect.top), Offset(rect.left + r + cL, rect.top), corner);
    canvas.drawLine(Offset(rect.left, rect.top + r), Offset(rect.left, rect.top + r + cL), corner);
    // HD
    canvas.drawLine(Offset(rect.right - r, rect.top), Offset(rect.right - r - cL, rect.top), corner);
    canvas.drawLine(Offset(rect.right, rect.top + r), Offset(rect.right, rect.top + r + cL), corner);
    // BG
    canvas.drawLine(Offset(rect.left + r, rect.bottom), Offset(rect.left + r + cL, rect.bottom), corner);
    canvas.drawLine(Offset(rect.left, rect.bottom - r), Offset(rect.left, rect.bottom - r - cL), corner);
    // BD
    canvas.drawLine(Offset(rect.right - r, rect.bottom), Offset(rect.right - r - cL, rect.bottom), corner);
    canvas.drawLine(Offset(rect.right, rect.bottom - r), Offset(rect.right, rect.bottom - r - cL), corner);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter old) => old.scale != scale;
}