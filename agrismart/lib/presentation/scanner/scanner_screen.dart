// lib/presentation/scanner/scanner_screen.dart
// Sprint 2 — Fixes :
//   1. Int8 preprocessing pour modèle quantifié
//   2. Timer 800ms au lieu de 200ms → plus de buffer overflow
//   3. Auto-navigation désactivée en dev (bouton manuel uniquement)
//   4. Pas de résultat simulé au démarrage

import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tflite;
import '../../core/theme/app_colors.dart';
import '../../core/router/route_names.dart';
import '../../core/services/tflite_loader.dart';
import '../../data/ml/prediction_aggregator.dart';
import '../../data/ml/image_preprocessor.dart' hide TensorType;

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with TickerProviderStateMixin {

  CameraController? _cameraController;
  bool _cameraInitialized = false;
  bool _isProcessing = false;
  bool _flashOn = false;
  bool _navigating = false;

  final _aggregator = PredictionAggregator();
  AggregatedPrediction? _currentPrediction;
  Timer? _frameTimer;

  late AnimationController _reticleController;
  late Animation<double> _reticlePulse;
  late AnimationController _resultController;
  late Animation<double> _resultFade;

  List<String> _labels = [];

  // Type de tenseur détecté automatiquement depuis le modèle
  late tflite.TensorType _tensorType;

  @override
  void initState() {
    super.initState();

    _reticleController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);
    _reticlePulse = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _reticleController, curve: Curves.easeInOut),
    );

    _resultController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _resultFade = CurveTween(curve: Curves.easeOut).animate(_resultController);

    _loadLabels();
    _detectTensorType();
    _initCamera();
  }

  // ── Détecter automatiquement le type de tenseur du modèle ─────
  void _detectTensorType() {
    final notifier = ref.read(tfliteLoaderProvider.notifier);
    final interpreter = notifier.interpreter;
    if (interpreter == null) return;

    try {
      final inputTensor = interpreter.getInputTensor(0);
      // TfLiteType.int8 = 9, float32 = 1
      _tensorType = inputTensor.type.name.toLowerCase().contains('int8')
          ? tflite.TensorType.int8
          : tflite.TensorType.float32;
      debugPrint('✅ Type tenseur détecté : $_tensorType');
    } catch (e) {
      debugPrint('⚠️  Impossible de détecter le type, on utilise int8 par défaut');
      _tensorType = tflite.TensorType.int8;
    }
  }

  Future<void> _loadLabels() async {
    try {
      final raw = await rootBundle.loadString('assets/ml/labels.txt');
      setState(() {
        _labels = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      });
      debugPrint('✅ Labels chargés : $_labels');
    } catch (e) {
      _labels = ['Bacterienne', 'Fongique', 'Parasitaire', 'Saine', 'Virale'];
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.low, // LOW pour éviter le buffer overflow
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _cameraInitialized = true);
        _startFrameProcessor();
      }
    } catch (e) {
      debugPrint('Erreur caméra: $e');
    }
  }

  // ── FrameProcessor : 800ms entre captures ─────────────────────
  // 200ms causait le buffer overflow (Unable to acquire a buffer item)
  void _startFrameProcessor() {
    final modelState = ref.read(tfliteLoaderProvider);
    if (modelState != ModelLoadState.ready) return;

    _frameTimer = Timer.periodic(
      const Duration(milliseconds: 800), // FIXE : 200→800ms
      (_) => _processFrame(),
    );
  }

  Future<void> _processFrame() async {
    if (_isProcessing || _navigating) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isTakingPicture) return; // garde-fou supplémentaire

    _isProcessing = true;
    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await xFile.readAsBytes();
      await _runInference(bytes);
    } catch (e) {
      debugPrint('Frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ── Inférence avec bon type de tenseur ───────────────────────
  Future<void> _runInference(Uint8List imageBytes) async {
    if (_labels.isEmpty) return;
    final interpreter = ref.read(tfliteLoaderProvider.notifier).interpreter;
    if (interpreter == null) return;

    try {
      Map<String, double> probs;

      if (_tensorType == tflite.TensorType.int8) {
        // Modèle quantifié int8
        final inputFlat = ImagePreprocessor.preprocessInt8(imageBytes);
        final inputTensor = ImagePreprocessor.reshapeInt8(inputFlat);

        // Output int8 aussi pour modèle quantifié
        final outputRaw = List.filled(_labels.length, 0);
        final output = [outputRaw];
        interpreter.run(inputTensor, output);

        // Déquantifier : int8 → probabilité [0,1]
        // Les sorties sont des scores bruts, on applique softmax simple
        probs = _softmaxFromInt8(output[0].cast<int>());
      } else {
        // Modèle float32
        final inputFlat = ImagePreprocessor.preprocessFloat32(imageBytes);
        final inputTensor = ImagePreprocessor.reshapeFloat32(inputFlat);
        final outputRaw = List.filled(_labels.length, 0.0);
        final output = [outputRaw];
        interpreter.run(inputTensor, output);
        probs = {};
        for (int i = 0; i < _labels.length; i++) {
          probs[_labels[i]] = output[0][i];
        }
      }

      debugPrint('🌿 Prédiction : $probs');

      _aggregator.addFrame(probs);
      final prediction = _aggregator.result;

      if (mounted && prediction != null && !_navigating) {
        final wasActionable = _currentPrediction?.isActionable ?? false;
        setState(() => _currentPrediction = prediction);
        if (!wasActionable && prediction.isActionable) {
          _resultController.forward(from: 0);
        }
        // PAS d'auto-navigation — l'agriculteur appuie sur le bouton
      }
    } catch (e) {
      debugPrint('Inference error: $e');
    }
  }

  /// Softmax sur sorties int8 (scores bruts → probabilités)
  Map<String, double> _softmaxFromInt8(List<int> scores) {
    // Convertir en double
    final doubles = scores.map((s) => s.toDouble()).toList();
    // Stabilité numérique : soustraire le max
    final maxVal = doubles.reduce((a, b) => a > b ? a : b);
    final exps = doubles.map((s) => (s - maxVal)).map((s) => _exp(s)).toList();
    final sum = exps.reduce((a, b) => a + b);
    final probs = <String, double>{};
    for (int i = 0; i < _labels.length; i++) {
      probs[_labels[i]] = exps[i] / sum;
    }
    return probs;
  }

  double _exp(double x) {
    // Clamp pour éviter overflow
    if (x < -20) return 0.0;
    if (x > 20) return 1e9;
    return x < 0
        ? 1.0 / (1.0 + _expPos(-x))
        : _expPos(x);
  }

  double _expPos(double x) {
    // Taylor series approximation for e^x
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 15; i++) {
      term *= x / i;
      result += term;
      if (term.abs() < 1e-10) break;
    }
    return result;
  }

  // ── Galerie ───────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    try {
      _frameTimer?.cancel();
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (xFile == null) {
        _startFrameProcessor();
        return;
      }
      setState(() => _isProcessing = true);
      final bytes = await xFile.readAsBytes();
      await _runInference(bytes);
      setState(() => _isProcessing = false);
    } catch (e) {
      debugPrint('Gallery error: $e');
      setState(() => _isProcessing = false);
      _startFrameProcessor();
    }
  }

  // ── Capture manuelle → navigation ────────────────────────────
  Future<void> _captureManual() async {
    if (_navigating) return;

    if (_currentPrediction != null) {
      _navigateToResult(_currentPrediction!);
      return;
    }

    // Forcer une capture
    if (_cameraController != null && _cameraController!.value.isInitialized
        && !_cameraController!.value.isTakingPicture) {
      setState(() => _isProcessing = true);
      try {
        final xFile = await _cameraController!.takePicture();
        final bytes = await xFile.readAsBytes();
        await _runInference(bytes);
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }

    if (mounted && _currentPrediction != null && !_navigating) {
      _navigateToResult(_currentPrediction!);
    }
  }

  void _navigateToResult(AggregatedPrediction prediction) {
    if (_navigating || !mounted) return;
    _navigating = true;
    _frameTimer?.cancel();
    context.goNamed(
      RouteNames.resultName,
      extra: {
        'disease':    prediction.topLabel,
        'confidence': prediction.topConfidence,
        'severity':   _severityFromLabel(prediction.topLabel),
        'advice':     _adviceForDisease(prediction.topLabel),
      },
    );
  }

  void _goBack() {
    _frameTimer?.cancel();
    if (context.canPop()) context.pop();
    else context.goNamed(RouteNames.homeName);
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    setState(() => _flashOn = !_flashOn);
    await _cameraController!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
  }

  String _severityFromLabel(String label) => label == 'Saine' ? 'healthy' : 'danger';

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
    _frameTimer?.cancel();
    _reticleController.dispose();
    _resultController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modelState = ref.watch(tfliteLoaderProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // CameraPreview
          if (_cameraInitialized && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            _buildPlaceholder(modelState),

          // Overlay
          _ScannerOverlay(
            reticleAnimation: _reticlePulse,
            confidenceLevel: _currentPrediction?.confidenceLevel,
          ),

          // UI
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 14),
                _buildGuidanceMessage(modelState),
                const Spacer(),
                if (_currentPrediction != null && _currentPrediction!.isActionable)
                  FadeTransition(
                    opacity: _resultFade,
                    child: _LiveResultCard(prediction: _currentPrediction!),
                  ),
                const SizedBox(height: 16),
                _buildBottomControls(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ModelLoadState state) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2E20), Color(0xFF0D1A0F)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              state == ModelLoadState.unavailable
                  ? 'Modèle IA non disponible'
                  : 'Initialisation caméra…',
              style: const TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _CircleButton(icon: Icons.arrow_back_rounded, onTap: _goBack),
          const Spacer(),
          _CircleButton(
            icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            onTap: _toggleFlash, active: _flashOn,
          ),
          const SizedBox(width: 10),
          _CircleButton(icon: Icons.photo_library_rounded, onTap: _pickFromGallery),
        ],
      ),
    );
  }

  Widget _buildGuidanceMessage(ModelLoadState modelState) {
    final text = _isProcessing
        ? 'Analyse en cours…'
        : !modelState.isReady
            ? 'Mode aperçu — modèle non chargé'
            : _currentPrediction == null
                ? 'Centrez la feuille dans le cadre'
                : _currentPrediction!.guidanceMessage;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
    );
  }

  Widget _buildBottomControls() {
    final progress = (aggregator.frameCount / aggregator.windowSize).clamp(0.0, 1.0);
    final hasResult = _currentPrediction != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${aggregator.frameCount}/${aggregator.windowSize} frames',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  Text(
                    hasResult ? '${(_currentPrediction!.topConfidence * 100).toStringAsFixed(0)}%' : '--',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _isProcessing ? null : progress,
                  minHeight: 4,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    hasResult && _currentPrediction!.confidenceLevel == ConfidenceLevel.reliable
                        ? AppColors.primary
                        : hasResult && _currentPrediction!.confidenceLevel == ConfidenceLevel.probable
                            ? AppColors.warning
                            : Colors.white38,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _captureManual,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasResult ? AppColors.primary : Colors.white70, width: 3),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 62, height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isProcessing ? Colors.white24
                      : hasResult ? AppColors.primary : Colors.white,
                ),
                child: _isProcessing
                    ? const Center(child: SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
                    : Icon(
                        hasResult ? Icons.check_rounded : Icons.camera_rounded,
                        color: hasResult ? Colors.white : AppColors.primary, size: 30),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isProcessing ? 'Analyse…' : hasResult ? 'Voir le résultat' : 'Forcer la capture',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  PredictionAggregator get aggregator => _aggregator;
}

extension on ModelLoadState {
  bool get isReady => this == ModelLoadState.ready;
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap, this.active = false});
  final IconData icon; final VoidCallback onTap; final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.8) : Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _LiveResultCard extends StatelessWidget {
  const _LiveResultCard({required this.prediction});
  final AggregatedPrediction prediction;

  Color get _color {
    switch (prediction.confidenceLevel) {
      case ConfidenceLevel.reliable: return AppColors.primary;
      case ConfidenceLevel.probable: return AppColors.warning;
      case ConfidenceLevel.uncertain: return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.6), width: 1.5),
      ),
      child: Row(
        children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: _color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(
              prediction.confidenceLevel == ConfidenceLevel.reliable
                  ? Icons.check_circle_rounded : Icons.pending_rounded,
              color: _color, size: 26)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prediction.topLabel, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              Text(prediction.guidanceMessage, style: TextStyle(color: _color, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          )),
          Text('${(prediction.topConfidence * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: _color, fontSize: 26, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.reticleAnimation, this.confidenceLevel});
  final Animation<double> reticleAnimation;
  final ConfidenceLevel? confidenceLevel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: reticleAnimation,
      builder: (_, __) => CustomPaint(
        painter: _OverlayPainter(reticleScale: reticleAnimation.value, confidenceLevel: confidenceLevel),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({required this.reticleScale, this.confidenceLevel});
  final double reticleScale;
  final ConfidenceLevel? confidenceLevel;

  Color get _reticleColor {
    switch (confidenceLevel) {
      case ConfidenceLevel.reliable: return AppColors.scannerReticleOk;
      case ConfidenceLevel.probable: return AppColors.warning;
      default: return AppColors.scannerReticle;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.58);
    final center = Offset(size.width / 2, size.height * 0.42);
    final rw = size.width * 0.72 * reticleScale;
    final rh = rw * 0.78;
    final rect = Rect.fromCenter(center: center, width: rw, height: rh);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, rect.top), overlayPaint);
    canvas.drawRect(Rect.fromLTWH(0, rect.bottom, size.width, size.height - rect.bottom), overlayPaint);
    canvas.drawRect(Rect.fromLTWH(0, rect.top, rect.left, rh), overlayPaint);
    canvas.drawRect(Rect.fromLTWH(rect.right, rect.top, size.width - rect.right, rh), overlayPaint);

    canvas.drawRRect(rrect, Paint()..color = _reticleColor..style = PaintingStyle.stroke..strokeWidth = 2);

    final cp = Paint()..color = _reticleColor..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;
    const cLen = 26.0; const r = 24.0;
    canvas.drawLine(Offset(rect.left + r, rect.top), Offset(rect.left + r + cLen, rect.top), cp);
    canvas.drawLine(Offset(rect.left, rect.top + r), Offset(rect.left, rect.top + r + cLen), cp);
    canvas.drawLine(Offset(rect.right - r, rect.top), Offset(rect.right - r - cLen, rect.top), cp);
    canvas.drawLine(Offset(rect.right, rect.top + r), Offset(rect.right, rect.top + r + cLen), cp);
    canvas.drawLine(Offset(rect.left + r, rect.bottom), Offset(rect.left + r + cLen, rect.bottom), cp);
    canvas.drawLine(Offset(rect.left, rect.bottom - r), Offset(rect.left, rect.bottom - r - cLen), cp);
    canvas.drawLine(Offset(rect.right - r, rect.bottom), Offset(rect.right - r - cLen, rect.bottom), cp);
    canvas.drawLine(Offset(rect.right, rect.bottom - r), Offset(rect.right, rect.bottom - r - cLen), cp);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.reticleScale != reticleScale || old.confidenceLevel != confidenceLevel;
}