import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import '../models/segmentation_result.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/image_utils.dart';
import 'model_postprocessing_service.dart';

/// Model B: segment_shelf_rows.onnx (YOLO11 seg, class: row).
/// Runs synchronously — it is only ever called from the inference worker isolate.
class ShelfSegmentationService {
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

  SegmentationResult runInference(LetterboxTensor lb) {
    final session = _session;
    if (session == null) throw StateError('ShelfSegmentationService not initialized');
    final sw = Stopwatch()..start();
    final input = OrtValueTensor.createTensorWithDataList(
        lb.tensor, [1, 3, AppConstants.inputSize, AppConstants.inputSize]);
    final runOptions = OrtRunOptions();
    final outputs = session.run(runOptions, {'images': input});
    input.release();
    runOptions.release();
    try {
      if (outputs.length < 2 || outputs[0] == null || outputs[1] == null) {
        throw Exception('Shelf segmentation model returned invalid outputs');
      }
      final out0 = ModelPostprocessingService.flatten(outputs[0]!.value);
      final protos = ModelPostprocessingService.flatten(outputs[1]!.value);
      return _postprocessor.parseSegmentationOutput(out0, protos, lb, sw.elapsedMicroseconds / 1000.0);
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
