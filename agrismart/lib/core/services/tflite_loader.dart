// lib/core/services/tflite_loader.dart
// Charge le modèle TFLite et initialise MlService

import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../data/ml/ml_service.dart';

enum ModelLoadState { idle, loading, ready, unavailable, error }

class TfliteLoaderNotifier extends StateNotifier<ModelLoadState> {
  TfliteLoaderNotifier() : super(ModelLoadState.idle);

  Interpreter? _interpreter;
  Interpreter? get interpreter => _interpreter;

  Future<void> loadModel() async {
    state = ModelLoadState.loading;
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/ml/agrismart.tflite',
        options: InterpreterOptions()..threads = 2,
      );

      // Initialiser MlService avec l'interpreter chargé
      MlService.instance.init(_interpreter!);

      // Log des dimensions pour vérification
      final inputShape  = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final inputType   = _interpreter!.getInputTensor(0).type;
      final outputType  = _interpreter!.getOutputTensor(0).type;

      dev.log('✅ Modèle chargé', name: 'TFLite');
      dev.log('   Input  : $inputShape — $inputType', name: 'TFLite');
      dev.log('   Output : $outputShape — $outputType', name: 'TFLite');

      state = ModelLoadState.ready;
    } catch (e) {
      dev.log('⚠️  Modèle absent : $e', name: 'TFLite');
      state = ModelLoadState.unavailable;
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }
}

final tfliteLoaderProvider =
    StateNotifierProvider<TfliteLoaderNotifier, ModelLoadState>(
  (ref) => TfliteLoaderNotifier(),
);