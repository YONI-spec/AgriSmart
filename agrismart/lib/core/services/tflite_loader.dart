// lib/core/services/tflite_loader.dart
// Chargement du modèle TFLite — NON-BLOQUANT si modèle absent
// L'app démarre normalement, le scanner affiche "Modèle non disponible"

import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

enum ModelLoadState { idle, loading, ready, unavailable, error }

class TfliteLoaderNotifier extends StateNotifier<ModelLoadState> {
  TfliteLoaderNotifier() : super(ModelLoadState.idle);

  Interpreter? _interpreter;
  Interpreter? get interpreter => _interpreter;
  bool get isReady => state == ModelLoadState.ready && _interpreter != null;

  Future<void> loadModel() async {
    state = ModelLoadState.loading;
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/ml/agrismart.tflite',
        options: InterpreterOptions()..threads = 2,
      );
      state = ModelLoadState.ready;
      dev.log('✅ Modèle TFLite chargé', name: 'TFLite');
    } catch (e) {
      dev.log('⚠️  Modèle absent ou corrompu : $e', name: 'TFLite');
      // NON-BLOQUANT : l'app continue, le scanner sera désactivé
      state = ModelLoadState.unavailable;
      // Ne pas rethrow — on laisse l'app démarrer
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