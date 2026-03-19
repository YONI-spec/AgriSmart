// lib/data/ml/prediction_aggregator.dart
// Fenêtre glissante 10 frames — vote majoritaire + seuils confiance
// Rend le diagnostic stable : évite les faux positifs sur 1 frame isolée

class PredictionAggregator {
  PredictionAggregator({
    this.windowSize = 10,
    this.minConfidenceReliable = 0.80,
    this.minConfidenceProbable = 0.60,
  });

  final int windowSize;
  final double minConfidenceReliable; // >80% → "Diagnostic fiable ✓"
  final double minConfidenceProbable; // 60-80% → "Résultat probable"

  final List<Map<String, double>> _window = [];

  // ── Ajouter une frame ─────────────────────────────────────────

  void addFrame(Map<String, double> probabilities) {
    _window.add(probabilities);
    if (_window.length > windowSize) _window.removeAt(0);
  }

  void reset() => _window.clear();

  int get frameCount => _window.length;
  bool get hasEnoughFrames => _window.length >= 3; // min 3 frames pour résultat

  // ── Résultat agrégé ───────────────────────────────────────────

  AggregatedPrediction? get result {
    if (_window.isEmpty) return null;

    // 1. Moyenne des probabilités sur la fenêtre
    final averaged = <String, double>{};
    for (final frame in _window) {
      for (final entry in frame.entries) {
        averaged[entry.key] = (averaged[entry.key] ?? 0.0) + entry.value;
      }
    }
    for (final key in averaged.keys) {
      averaged[key] = averaged[key]! / _window.length;
    }

    // 2. Top label
    final top = averaged.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    // 3. Niveau de confiance
    final level = _confidenceLevel(top.value);

    return AggregatedPrediction(
      topLabel: top.key,
      topConfidence: top.value,
      allAveraged: Map.unmodifiable(averaged),
      confidenceLevel: level,
      framesUsed: _window.length,
    );
  }

  ConfidenceLevel _confidenceLevel(double confidence) {
    if (confidence >= minConfidenceReliable) return ConfidenceLevel.reliable;
    if (confidence >= minConfidenceProbable) return ConfidenceLevel.probable;
    return ConfidenceLevel.uncertain;
  }
}

// ── Résultat agrégé ───────────────────────────────────────────────

class AggregatedPrediction {
  const AggregatedPrediction({
    required this.topLabel,
    required this.topConfidence,
    required this.allAveraged,
    required this.confidenceLevel,
    required this.framesUsed,
  });

  final String topLabel;
  final double topConfidence;
  final Map<String, double> allAveraged;
  final ConfidenceLevel confidenceLevel;
  final int framesUsed;

  String get guidanceMessage {
    switch (confidenceLevel) {
      case ConfidenceLevel.uncertain:
        return 'Continue de filmer…';
      case ConfidenceLevel.probable:
        return 'Résultat probable';
      case ConfidenceLevel.reliable:
        return 'Diagnostic fiable ✓';
    }
  }

  bool get isActionable =>
      confidenceLevel != ConfidenceLevel.uncertain;
}

enum ConfidenceLevel {
  uncertain,  // < 60%
  probable,   // 60–80%
  reliable,   // > 80%
}