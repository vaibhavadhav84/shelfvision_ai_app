import 'dart:ui';

import 'detection_result.dart';
import 'segmentation_result.dart';

class InferenceFrameResult {
  final DetectionResult detectionResult;
  final SegmentationResult segmentationResult;
  final double totalInferenceMs;
  final double fps;
  final DateTime timestamp;

  /// Size of the (rotated) source image that all box/mask coordinates refer to.
  /// Overlays use it to map coordinates onto the on-screen preview.
  final Size imageSize;

  const InferenceFrameResult({
    required this.detectionResult,
    required this.segmentationResult,
    required this.totalInferenceMs,
    required this.fps,
    required this.timestamp,
    this.imageSize = const Size(640, 640),
  });

  InferenceFrameResult copyWith({double? fps}) => InferenceFrameResult(
        detectionResult: detectionResult,
        segmentationResult: segmentationResult,
        totalInferenceMs: totalInferenceMs,
        fps: fps ?? this.fps,
        timestamp: timestamp,
        imageSize: imageSize,
      );
}
