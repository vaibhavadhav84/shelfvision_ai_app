import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import '../core/utils/image_utils.dart';
import '../data/models/inference_frame_result.dart';
import '../data/services/inference_pipeline_service.dart';

/// Thin facade over the background inference pipeline.
class AiPlatformService {
  static final AiPlatformService _instance = AiPlatformService._internal();
  static AiPlatformService get instance => _instance;
  AiPlatformService._internal();

  final InferencePipelineService _pipeline = InferencePipelineService();

  bool get isLoaded => _pipeline.isInitialized;
  bool get isBusy => _pipeline.isProcessing;

  Future<void> initialize() => _pipeline.initialize();

  /// Returns null when the frame was dropped because the worker is busy.
  Future<InferenceFrameResult?> processFrame(CameraImage frame, int sensorOrientation) {
    if (_pipeline.isProcessing || !_pipeline.isInitialized) return Future.value(null);
    return _pipeline.processFrame(YuvFrame.fromCameraImage(frame), sensorOrientation);
  }

  void resetTiming() => _pipeline.resetTiming();

  Future<InferenceFrameResult> processImageFile(File imageFile) =>
      _pipeline.processImageFile(imageFile.path);

  void dispose() => _pipeline.dispose();
}
