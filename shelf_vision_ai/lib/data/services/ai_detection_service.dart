import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import '../models/detection_result.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/image_utils.dart';
import 'model_postprocessing_service.dart';

/// Model A: detect_product_empty_space.onnx (YOLO11 detect, classes: empty, product).
/// Runs synchronously — it is only ever called from the inference worker isolate.
class AiDetectionService {
  OrtSession? _session;
  final ModelPostprocessingService _postprocessor = ModelPostprocessingService();

  bool get isInitialized => _session != null;

  void initialize(Uint8List modelBytes) {
    if (_session != null) return;
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(2)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    _session = OrtSession.fromBuffer(modelBytes, options);
    options.release();
  }

  DetectionResult runInference(LetterboxTensor lb) {
    final session = _session;
    if (session == null) throw StateError('AiDetectionService not initialized');
    final sw = Stopwatch()..start();
    final input = OrtValueTensor.createTensorWithDataList(
        lb.tensor, [1, 3, AppConstants.inputSize, AppConstants.inputSize]);
    final runOptions = OrtRunOptions();
    final outputs = session.run(runOptions, {'images': input});
    input.release();
    runOptions.release();
    try {
      if (outputs.isEmpty || outputs[0] == null) {
        throw Exception('Detection model returned empty output');
      }
      final flat = ModelPostprocessingService.flatten(outputs[0]!.value);
      return _postprocessor.parseDetectionOutput(flat, lb, sw.elapsedMicroseconds / 1000.0);
    } finally {
      for (final o in outputs) {
        o?.release();
      }
    }
  }

  void dispose() {
    _session?.release();
    _session = null;
  }
}
