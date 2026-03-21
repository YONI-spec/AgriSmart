// lib/data/ml/image_preprocessor.dart
// Preprocessing pour MobileNetV3Small quantifié int8
//
// Entraîné avec : img = (img / 127.5) - 1.0  → [-1.0, 1.0]
// TFLite int8 quantifié attend : int8 = round((float - zero_point) / scale)
//
// MAIS : avec converter.inference_input_type = tf.int8,
// TFLite attend directement les int8 quantifiés depuis [-1,1].
// La formule de quantification de MobileNetV3 donne :
//   scale ≈ 1/128, zero_point = 0
//   donc : int8 = clamp(round(float * 128), -128, 127)
// Ce qui équivaut à : pixel → (pixel / 127.5 - 1.0) * 128
// Simplifié      : int8 = pixel - 128  (approximation valide)

import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  static const int inputSize = 224;

  /// Pour MobileNetV3 quantifié int8 entraîné avec (pixel/127.5 - 1.0)
  /// Formule : int8_value = pixel - 128
  /// Résultat shape [1, 224, 224, 3] de type int
  static List<List<List<List<int>>>> prepareMobileNetV3Int8(
      Uint8List imageBytes) {
    final resized = _resize(imageBytes);
    return List.generate(1, (_) =>
      List.generate(inputSize, (y) =>
        List.generate(inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            (pixel.r.toInt() - 128).clamp(-128, 127),
            (pixel.g.toInt() - 128).clamp(-128, 127),
            (pixel.b.toInt() - 128).clamp(-128, 127),
          ];
        }),
      ),
    );
  }

  /// Pour modèle float32 entraîné avec (pixel/127.5 - 1.0)
  static List<List<List<List<double>>>> prepareMobileNetV3Float(
      Uint8List imageBytes) {
    final resized = _resize(imageBytes);
    return List.generate(1, (_) =>
      List.generate(inputSize, (y) =>
        List.generate(inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r / 127.5 - 1.0,
            pixel.g / 127.5 - 1.0,
            pixel.b / 127.5 - 1.0,
          ];
        }),
      ),
    );
  }

  static img.Image _resize(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Image invalide');
    return img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );
  }
}