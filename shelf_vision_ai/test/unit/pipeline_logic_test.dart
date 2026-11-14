import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shelf_vision_ai/core/utils/coordinate_utils.dart';
import 'package:shelf_vision_ai/core/utils/image_utils.dart';
import 'package:shelf_vision_ai/data/models/detection_result.dart';
import 'package:shelf_vision_ai/data/models/inference_frame_result.dart';
import 'package:shelf_vision_ai/data/models/segmentation_result.dart';
import 'package:shelf_vision_ai/data/models/shelf_analytics.dart';
import 'package:shelf_vision_ai/data/services/model_postprocessing_service.dart';

/// Builds a grayscale YUV frame (U=V=128) with row padding in every plane.
YuvFrame _frame(int w, int h, int Function(int x, int y) luma, {int pad = 16}) {
  final yStride = w + pad;
  final uvStride = (w ~/ 2) + pad;
  final y = Uint8List(yStride * h);
  for (int j = 0; j < h; j++) {
    for (int i = 0; i < w; i++) {
      y[j * yStride + i] = luma(i, j);
    }
  }
  final uv = Uint8List(uvStride * (h ~/ 2))..fillRange(0, uvStride * (h ~/ 2), 128);
  return YuvFrame(
      width: w, height: h, y: y, u: uv, v: Uint8List.fromList(uv),
      yRowStride: yStride, uvRowStride: uvStride, uvPixelStride: 1);
}

double _px(LetterboxTensor t, int x, int y) => t.tensor[y * 640 + x];

void main() {
  group('YUV → letterboxed tensor', () {
    test('handles row stride padding and 90° sensor rotation', () {
      // Landscape sensor frame 64x32; bright pixels only in the LEFT half.
      final f = _frame(64, 32, (x, y) => x < 32 ? 255 : 0);
      final t = ImageUtils.yuvToLetterboxTensor(f, 90, 640);
      // Rotated to portrait 32x64 → scale 10, padX = 160.
      expect(t.origWidth, 32);
      expect(t.origHeight, 64);
      expect(t.scale, 10);
      expect(t.padX, 160);
      expect(t.padY, 0);
      // Clockwise rotation: the sensor's left half becomes the TOP half.
      expect(_px(t, 320, 100), closeTo(1.0, 1e-6));
      expect(_px(t, 320, 540), closeTo(0.0, 1e-6));
      // Letterbox padding is gray 114.
      expect(_px(t, 10, 320), closeTo(114 / 255, 1e-6));
    });

    test('no rotation keeps orientation', () {
      final f = _frame(64, 32, (x, y) => x < 32 ? 255 : 0);
      final t = ImageUtils.yuvToLetterboxTensor(f, 0, 640);
      expect(t.origWidth, 64);
      expect(_px(t, 100, 320), closeTo(1.0, 1e-6));
      expect(_px(t, 540, 320), closeTo(0.0, 1e-6));
    });
  });

  group('ImageToViewMapper', () {
    test('cover fills and crops the long side', () {
      final m = ImageToViewMapper(const Size(480, 640), const Size(400, 900), BoxFit.cover);
      expect(m.scale, closeTo(900 / 640, 1e-9));
      expect(m.mapOffset(const Offset(240, 320)).dx, closeTo(200, 1e-6)); // centre stays centre
      expect(m.mapOffset(const Offset(240, 320)).dy, closeTo(450, 1e-6));
    });

    test('contain letterboxes', () {
      final m = ImageToViewMapper(const Size(1000, 500), const Size(400, 400), BoxFit.contain);
      expect(m.mapRect(const Rect.fromLTRB(0, 0, 1000, 500)), const Rect.fromLTRB(0, 100, 400, 300));
    });
  });

  group('Postprocessing', () {
    test('decodes YOLO detect output [1,6,8400] into image coordinates', () {
      final out = Float32List(6 * 8400);
      void anchor(int a, double cx, double cy, double w, double h, double sEmpty, double sProd) {
        out[a] = cx;
        out[8400 + a] = cy;
        out[2 * 8400 + a] = w;
        out[3 * 8400 + a] = h;
        out[4 * 8400 + a] = sEmpty;
        out[5 * 8400 + a] = sProd;
      }

      anchor(0, 320, 320, 100, 100, 0.1, 0.9); // product
      anchor(1, 322, 322, 100, 100, 0.1, 0.8); // duplicate → suppressed by NMS
      anchor(2, 300, 100, 40, 40, 0.7, 0.2); // empty
      anchor(4, 50, 100, 40, 40, 0.9, 0.1); // inside letterbox padding → dropped
      anchor(3, 500, 500, 40, 40, 0.1, 0.1); // below threshold
      // Image 320x640 letterboxed: scale 1, padX 160.
      final lb = LetterboxTensor(Float32List(0), 160, 0, 1, 320, 640);
      final r = ModelPostprocessingService().parseDetectionOutput(out, lb, 0);
      expect(r.productCount, 1);
      expect(r.emptyCount, 1);
      expect(r.products.first.rect, const Rect.fromLTRB(110, 270, 210, 370));
      expect(r.products.first.confidence, closeTo(0.9, 1e-6));
    });
  });

  group('ShelfAnalytics', () {
    test('assigns detections to rows and computes empty %', () {
      DetectionBox box(Rect r, String l) =>
          DetectionBox(rect: r, classId: l == 'product' ? 1 : 0, label: l, confidence: 0.9);
      final result = InferenceFrameResult(
        detectionResult: DetectionResult(
          products: [box(const Rect.fromLTWH(0, 10, 10, 10), 'product'), box(const Rect.fromLTWH(0, 110, 10, 10), 'product')],
          emptySpaces: [box(const Rect.fromLTWH(20, 110, 10, 10), 'empty')],
          inferenceTimeMs: 0,
        ),
        segmentationResult: const SegmentationResult(rows: [
          SegmentedRow(boundingBox: Rect.fromLTWH(0, 0, 100, 40), maskContour: [], confidence: 0.8),
          SegmentedRow(boundingBox: Rect.fromLTWH(0, 100, 100, 40), maskContour: [], confidence: 0.8),
        ], inferenceTimeMs: 0),
        totalInferenceMs: 0,
        fps: 0,
        timestamp: DateTime(2026),
      );
      final a = ShelfAnalytics.fromResult(result);
      expect(a.rows[0].products, 1);
      expect(a.rows[0].emptyPercent, 0);
      expect(a.rows[1].emptySlots, 1);
      expect(a.rows[1].emptyPercent, closeTo(50, 1e-9));
      expect(a.rows[1].needsRestock, isTrue);
      expect(result.segmentationResult.shelfArea, const Rect.fromLTRB(0, 0, 100, 140));
    });
  });

  test('letterbox of still image keeps original size for coordinate mapping', () {
    final t = ImageUtils.imageToLetterboxTensor(img.Image(width: 300, height: 600), 640);
    expect(t.origWidth, 300);
    expect(t.origHeight, 600);
    expect(t.padX, closeTo(160, 1));
  });
}
