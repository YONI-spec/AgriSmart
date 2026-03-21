// lib/data/ml/ml_service.dart
// MobileNetV3Small quantifié int8
// Normalisation entraînement : (pixel / 127.5) - 1.0  → [-1, 1]
// Input TFLite int8          : pixel - 128             → [-128, 127]
// Output TFLite int8         : déquantifié via scale/zero_point

import 'dart:typed_data';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'image_preprocessor.dart';

const List<String> kLabels = [
  'Bacterienne',
  'Fongique',
  'Parasitaire',
  'Saine',
  'Virale',
];

class PredictionResult {
  const PredictionResult({
    required this.label,
    required this.confidence,
    required this.allScores,
  });

  final String label;
  final double confidence;
  final Map<String, double> allScores;

  bool get isSaine => label == 'Saine';

  String get severityKey {
    if (isSaine) return 'healthy';
    if (confidence >= 0.80) return 'danger';
    return 'warning';
  }

  @override
  String toString() =>
      'PredictionResult($label: ${(confidence * 100).toStringAsFixed(1)}%)';
}

class MlService {
  MlService._();
  static final MlService instance = MlService._();

  Interpreter? _interpreter;

  // Paramètres déquantification sortie
  double _outScale     = 1.0 / 256.0;
  int    _outZeroPoint = -128;

  void init(Interpreter interpreter) {
    _interpreter = interpreter;

    try {
      final inTensor  = interpreter.getInputTensor(0);
      final outTensor = interpreter.getOutputTensor(0);

      // Lire les vrais paramètres de quantification
      if (outTensor.params.scale != 0.0) {
        _outScale     = outTensor.params.scale;
        _outZeroPoint = outTensor.params.zeroPoint;
      }

      // ignore: avoid_print
      print('🧠 MobileNetV3 AgriSmart');
      // ignore: avoid_print
      print('   Input  : ${inTensor.shape} — ${inTensor.type}');
      // ignore: avoid_print
      print('   Output : ${outTensor.shape} — ${outTensor.type}');
      // ignore: avoid_print
      print('   Out scale=$_outScale  zero=$_outZeroPoint');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️  Métadonnées non lisibles : $e');
    }
  }

  bool get isReady => _interpreter != null;

  Future<PredictionResult> predict(Uint8List imageBytes) async {
    final interpreter = _interpreter;
    if (interpreter == null) throw StateError('Modèle non initialisé');

    // 1. Preprocessing MobileNetV3 : pixel - 128 → [-128, 127]
    final input = ImagePreprocessor.prepareMobileNetV3Int8(imageBytes);

    // 2. Buffer sortie int8 [1, 5]
    final output = [List.filled(kLabels.length, 0)];

    // 3. Inférence
    interpreter.run(input, output);

    // 4. Déquantifier les sorties int8 → logits float
    //    float = (int8 - zero_point) * scale
    final logits = output[0]
        .map((v) => (v - _outZeroPoint) * _outScale)
        .toList();

    // ignore: avoid_print
    print('🔢 Logits déquantifiés : $logits');

    // 5. Softmax → probabilités
    final probs = _softmax(logits);

    final allScores = <String, double>{
      for (int i = 0; i < kLabels.length; i++) kLabels[i]: probs[i],
    };

    // ignore: avoid_print
    print('🌿 Scores : $allScores');

    final top = allScores.entries
        .reduce((a, b) => a.value > b.value ? a : b);

    return PredictionResult(
      label:      top.key,
      confidence: top.value,
      allScores:  allScores,
    );
  }

  Future<PredictionResult> predictMultiple(List<Uint8List> images) async {
    if (images.isEmpty) throw ArgumentError('Au moins une image requise');
    if (images.length == 1) return predict(images.first);

    final results = <PredictionResult>[];
    for (final img in images) {
      results.add(await predict(img));
    }

    final averaged = <String, double>{};
    for (final label in kLabels) {
      averaged[label] = results
          .map((r) => r.allScores[label] ?? 0.0)
          .reduce((a, b) => a + b) / results.length;
    }

    final top = averaged.entries
        .reduce((a, b) => a.value > b.value ? a : b);

    return PredictionResult(
      label:      top.key,
      confidence: top.value,
      allScores:  averaged,
    );
  }

  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];
    final maxVal = logits.reduce(math.max);
    final exps   = logits.map((x) => math.exp(x - maxVal)).toList();
    final sum    = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }
}