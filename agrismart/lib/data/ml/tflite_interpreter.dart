// lib/data/ml/tflite_interpreter.dart
// Inférence TFLite — ISOLATE séparé, thread UI protégé
// FrameProcessor : 1 frame / 200ms → probabilités

import 'dart:isolate';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'image_preprocessor.dart';

// ── Message envoyé à l'Isolate ────────────────────────────────────
class _InferenceRequest {
  const _InferenceRequest({
    required this.imageBytes,
    required this.sendPort,
  });
  final Uint8List imageBytes;
  final SendPort sendPort;
}

// ── Résultat retourné par l'Isolate ──────────────────────────────
class InferenceResult {
  const InferenceResult({
    required this.probabilities,
    required this.topLabel,
    required this.topConfidence,
    required this.durationMs,
  });

  final Map<String, double> probabilities;
  final String topLabel;
  final double topConfidence;
  final int durationMs;

  @override
  String toString() =>
      'InferenceResult($topLabel: ${(topConfidence * 100).toStringAsFixed(1)}%, '
      '${durationMs}ms)';
}

// ── Worker Isolate principal ──────────────────────────────────────
class TfliteIsolateWorker {
  TfliteIsolateWorker._();
  static final TfliteIsolateWorker instance = TfliteIsolateWorker._();

  Interpreter? _interpreter;
  List<String> _labels = [];

  /// Initialiser le modèle (appelé une fois après le splash)
  Future<void> init(Interpreter interpreter, List<String> labels) async {
    _interpreter = interpreter;
    _labels = labels;
  }

  /// Lancer une inférence dans un Isolate séparé
  /// → ne bloque JAMAIS le thread UI
  Future<InferenceResult> runInference(Uint8List imageBytes) async {
    if (_interpreter == null) {
      throw StateError('Modèle non initialisé');
    }

    return await Isolate.run(() => _inferenceTask(imageBytes, _labels));
  }

  /// Tâche d'inférence — s'exécute dans l'Isolate
  static InferenceResult _inferenceTask(
    Uint8List imageBytes,
    List<String> labels,
  ) {
    final stopwatch = Stopwatch()..start();

    // 1. Preprocessing (int8 par défaut — modèle quantifié)
    final inputFlat = ImagePreprocessor.preprocessInt8(imageBytes);
    final inputTensor = ImagePreprocessor.reshapeInt8(inputFlat);

    // 2. Préparer le buffer de sortie [1, numClasses]
    final outputBuffer = List.filled(labels.length, 0.0);
    final output = [outputBuffer];

    // NOTE : En Isolate, on ne peut pas utiliser l'Interpreter Flutter
    // directement (il n'est pas Sendable). Pour le Sprint 2 on simule
    // la structure — le vrai chargement en Isolate sera fait avec
    // Interpreter.fromAsset() à l'intérieur de l'Isolate.
    // Voir _inferenceTaskWithModel() pour la version complète.

    // Simulation pour développement sans modèle
    final probs = _simulatePrediction(labels);
    stopwatch.stop();

    final topEntry = probs.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    return InferenceResult(
      probabilities: probs,
      topLabel: topEntry.key,
      topConfidence: topEntry.value,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Version complète — chargement du modèle dans l'Isolate
  /// (utilisée quand le .tflite est disponible)
  static Future<InferenceResult> runWithModel(Uint8List imageBytes) async {
    return await Isolate.run(() async {
      final stopwatch = Stopwatch()..start();

      // Charger le modèle dans l'Isolate (thread séparé)
      final interpreter = await Interpreter.fromAsset(
        'assets/ml/agrismart.tflite',
        options: InterpreterOptions()..threads = 1,
      );

      // Lire les labels
      // Labels réels du modèle AgriSmart
      final labels = <String>['Bacterienne', 'Fongique', 'Parasitaire', 'Saine', 'Virale'];

      final inputFlat = ImagePreprocessor.preprocessInt8(imageBytes);
      final inputTensor = ImagePreprocessor.reshapeInt8(inputFlat);

      final outputBuffer = List.filled(labels.length, 0);
      final output = [outputBuffer];

      interpreter.run(inputTensor, output);
      interpreter.close();

      final probs = <String, double>{};
      for (int i = 0; i < labels.length; i++) {
        probs[labels[i]] = (output[0][i] as num).toDouble();
      }

      stopwatch.stop();
      final topEntry = probs.entries.reduce((a, b) => a.value > b.value ? a : b);

      return InferenceResult(
        probabilities: probs,
        topLabel: topEntry.key,
        topConfidence: topEntry.value,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    });
  }

  /// Simulation de prédiction — DEV uniquement
  static Map<String, double> _simulatePrediction(List<String> labels) {
    return {
      'Bacterienne': 0.04,
      'Fongique':    0.82,
      'Parasitaire': 0.05,
      'Saine':       0.06,
      'Virale':      0.03,
    };
  }
}