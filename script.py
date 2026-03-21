import numpy as np
import tensorflow as tf

# Charge le modèle TFLite
interpreter = tf.lite.Interpreter(
    model_path='C:/Users/agbod/Desktop/AgriSmart/agrismart/assets/ml/agrismart.tflite'
)
interpreter.allocate_tensors()

inp  = interpreter.get_input_details()[0]
out  = interpreter.get_output_details()[0]

print('=== INPUT ===')
print('  Shape     :', inp['shape'])
print('  dtype     :', inp['dtype'])
print('  scale     :', inp['quantization_parameters']['scales'])
print('  zero_point:', inp['quantization_parameters']['zero_points'])

print('=== OUTPUT ===')
print('  Shape     :', out['shape'])
print('  dtype     :', out['dtype'])
print('  scale     :', out['quantization_parameters']['scales'])
print('  zero_point:', out['quantization_parameters']['zero_points'])