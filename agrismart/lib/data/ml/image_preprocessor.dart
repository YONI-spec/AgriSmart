// lib/data/ml/image_preprocessor.dart
// Preprocessing image — supporte Float32 ET Int8 selon le modèle

import 'dart:typed_data';
import 'package:image/image.dart' as img;

enum TensorType { float32, int8 }

class ImagePreprocessor {
  static const int inputSize = 160;

  /// Retourne un Int8List normalisé [-128, 127] pour modèle quantifié int8
  static Int8List preprocessInt8(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Impossible de décoder l\'image');

    final resized = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Int8 quantifié : pixel [0,255] → [-128, 127]
    // Formule : int8_value = pixel - 128
    final input = Int8List(inputSize * inputSize * 3);
    int idx = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixelSafe(x, y) as img.Pixel;
        input[idx++] = (pixel.r - 128).clamp(-128, 127).toInt();
        input[idx++] = (pixel.g - 128).clamp(-128, 127).toInt();
        input[idx++] = (pixel.b - 128).clamp(-128, 127).toInt();
      }
    }
    return input;
  }

  /// Retourne un Float32List normalisé [0.0, 1.0] pour modèle non quantifié
  static Float32List preprocessFloat32(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Impossible de décoder l\'image');

    final resized = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    final input = Float32List(inputSize * inputSize * 3);
    int idx = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixelSafe(x, y) as img.Pixel;
        input[idx++] = pixel.r / 255.0;
        input[idx++] = pixel.g / 255.0;
        input[idx++] = pixel.b / 255.0;
      }
    }
    return input;
  }

  /// Reshape Int8 → List 4D pour tflite_flutter
  static List<List<List<List<int>>>> reshapeInt8(Int8List flat) {
    return List.generate(1, (_) =>
      List.generate(inputSize, (y) =>
        List.generate(inputSize, (x) =>
          List.generate(3, (c) => flat[(y * inputSize + x) * 3 + c]),
        ),
      ),
    );
  }

  /// Reshape Float32 → List 4D pour tflite_flutter
  static List<List<List<List<double>>>> reshapeFloat32(Float32List flat) {
    return List.generate(1, (_) =>
      List.generate(inputSize, (y) =>
        List.generate(inputSize, (x) =>
          List.generate(3, (c) => flat[(y * inputSize + x) * 3 + c]),
        ),
      ),
    );
  }
}