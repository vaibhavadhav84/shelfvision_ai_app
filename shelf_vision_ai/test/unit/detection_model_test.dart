import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_vision_ai/core/constants/app_constants.dart';
import 'package:shelf_vision_ai/data/models/detection_result.dart';
import 'package:shelf_vision_ai/data/models/segmentation_result.dart';
import 'package:shelf_vision_ai/data/models/inference_frame_result.dart';

void main() {
  group('Data Models & Class Mapping Tests', () {
    test('DetectionBox initializes correctly with class mapping', () {
      const boxEmpty = DetectionBox(
        rect: Rect.fromLTRB(10, 10, 50, 50),
        classId: AppConstants.classEmpty,
        label: 'empty',
        confidence: 0.85,
      );

      const boxProduct = DetectionBox(
        rect: Rect.fromLTRB(60, 60, 100, 100),
        classId: AppConstants.classProduct,
        label: 'product',
        confidence: 0.92,
      );

      expect(boxEmpty.classId, 0);
      expect(boxEmpty.label, 'empty');
      expect(boxEmpty.confidence, 0.85);

      expect(boxProduct.classId, 1);
      expect(boxProduct.label, 'product');
      expect(boxProduct.confidence, 0.92);
    });

    test('DetectionResult aggregates products and empty spaces accurately', () {
      final result = DetectionResult(
        products: [
          const DetectionBox(
            rect: Rect.fromLTRB(0, 0, 10, 10),
            classId: AppConstants.classProduct,
            label: 'product',
            confidence: 0.90,
          ),
          const DetectionBox(
            rect: Rect.fromLTRB(20, 20, 30, 30),
            classId: AppConstants.classProduct,
            label: 'product',
            confidence: 0.88,
          ),
        ],
        emptySpaces: [
          const DetectionBox(
            rect: Rect.fromLTRB(50, 50, 70, 70),
            classId: AppConstants.classEmpty,
            label: 'empty',
            confidence: 0.75,
          ),
        ],
        inferenceTimeMs: 45.2,
      );

      expect(result.productCount, 2);
      expect(result.emptyCount, 1);
      expect(result.all.length, 3);
      expect(result.inferenceTimeMs, 45.2);
    });

    test('SegmentationResult handles rows and contours correctly', () {
      final row = SegmentedRow(
        boundingBox: const Rect.fromLTWH(0, 100, 400, 50),
        maskContour: [
          const Offset(0, 100),
          const Offset(400, 100),
          const Offset(400, 150),
          const Offset(0, 150),
        ],
        confidence: 0.68,
      );

      final segResult = SegmentationResult(
        rows: [row],
        inferenceTimeMs: 52.0,
      );

      expect(segResult.rowCount, 1);
      expect(segResult.rows.first.confidence, 0.68);
      expect(segResult.rows.first.maskContour.length, 4);
    });

    test('InferenceFrameResult combines detection and segmentation', () {
      final frame = InferenceFrameResult(
        detectionResult: const DetectionResult(
          products: [],
          emptySpaces: [],
          inferenceTimeMs: 20.0,
        ),
        segmentationResult: const SegmentationResult(
          rows: [],
          inferenceTimeMs: 25.0,
        ),
        totalInferenceMs: 45.0,
        fps: 4.8,
        timestamp: DateTime.now(),
      );

      expect(frame.totalInferenceMs, 45.0);
      expect(frame.fps, 4.8);
    });
  });
}

