// lib/core/services/tflite_loader.dart
// Chargement du modèle TFLite au démarrage

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// État du chargement
enum ModelLoadState { idle, loading, ready, error }

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
      state = ModelLoadState.ready;
    } catch (e) {
      state = ModelLoadState.error;
      rethrow;
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