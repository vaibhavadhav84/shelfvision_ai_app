import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_vision_ai/core/utils/coordinate_utils.dart';

void main() {
  group('CoordinateUtils Tests', () {
    test('modelToImageCoords correctly maps unpadded coordinates', () {
      final offset = CoordinateUtils.modelToImageCoords(320, 320, 0, 0, 1.0);
      expect(offset.dx, 320.0);
      expect(offset.dy, 320.0);
    });

    test('modelToImageCoords removes letterbox padding and scales correctly', () {
      // Suppose image is 1280x720. When resized into 640x640:
      // scale = 640 / 1280 = 0.5.
      // newW = 640, newH = 360.
      // padX = 0, padY = (640 - 360) / 2 = 140.
      final offset = CoordinateUtils.modelToImageCoords(320, 140, 0, 140, 0.5);
      expect(offset.dx, 640.0);
      expect(offset.dy, 0.0);
    });

    test('modelBoxToDisplayRect scales box to display bounds', () {
      final box = [100.0, 100.0, 300.0, 300.0];
      final rect = CoordinateUtils.modelBoxToDisplayRect(
        box,
        0,
        0,
        1.0,
        640,
        640,
        320,
        320,
      );

      expect(rect.left, 50.0);
      expect(rect.top, 50.0);
      expect(rect.right, 150.0);
      expect(rect.bottom, 150.0);
    });

    test('iou computes intersection over union accurately', () {
      final rectA = const Rect.fromLTWH(0, 0, 100, 100);
      final rectB = const Rect.fromLTWH(50, 0, 100, 100);
      // Area A = 10000, Area B = 10000.
      // Intersection = 50 * 100 = 5000.
      // Union = 10000 + 10000 - 5000 = 15000.
      // IoU = 5000 / 15000 = 1/3 ~ 0.3333
      final iou = CoordinateUtils.iou(rectA, rectB);
      expect(iou, closeTo(0.3333, 0.001));
    });

    test('iou returns 0 for non-intersecting rects', () {
      final rectA = const Rect.fromLTWH(0, 0, 50, 50);
      final rectB = const Rect.fromLTWH(100, 100, 50, 50);
      expect(CoordinateUtils.iou(rectA, rectB), 0.0);
    });
  });
}

