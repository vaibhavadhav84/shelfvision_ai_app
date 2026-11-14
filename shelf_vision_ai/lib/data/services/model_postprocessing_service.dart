import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../models/segmentation_result.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/coordinate_utils.dart';
import '../../core/utils/image_utils.dart';

/// Decodes raw YOLO11 ONNX outputs. All returned coordinates are in the
/// ORIGINAL (rotated) image pixel space — the UI maps them to the screen.
class ModelPostprocessingService {
  static const int _numAnchors = 8400;
  static const int _maxDetections = 300;
  static const int _protoSize = 160;
  static const int _numMaskCoeffs = 32;

  /// Flattens the nested List returned by `OrtValueTensor.value`
  /// (shape [1, C, N] or [1, C, H, W]) into a contiguous Float32List.
  static Float32List flatten(Object? nested) {
    final out = <double>[];
    void walk(Object? v) {
      if (v is List) {
        if (v.isNotEmpty && v.first is num) {
          for (final e in v) {
            out.add((e as num).toDouble());
          }
        } else {
          for (final e in v) {
            walk(e);
          }
        }
      }
    }

    walk(nested);
    return Float32List.fromList(out);
  }

  List<int> _nms(List<List<double>> boxes, List<double> scores, double iouThreshold) {
    final List<int> order = List.generate(scores.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final List<int> kept = [];
    final List<bool> suppressed = List.filled(order.length, false);
    for (int i = 0; i < order.length && kept.length < _maxDetections; i++) {
      if (suppressed[i]) continue;
      kept.add(order[i]);
      final bi = boxes[order[i]];
      final Rect ra = Rect.fromLTRB(bi[0], bi[1], bi[2], bi[3]);
      for (int j = i + 1; j < order.length; j++) {
        if (suppressed[j]) continue;
        final bj = boxes[order[j]];
        if (CoordinateUtils.iou(ra, Rect.fromLTRB(bj[0], bj[1], bj[2], bj[3])) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    return kept;
  }

  /// Detection head output: [1, 6, 8400] = cx, cy, w, h, score(empty), score(product).
  DetectionResult parseDetectionOutput(Float32List out, LetterboxTensor lb, double inferenceMs) {
    const int n = _numAnchors;
    final perClassBoxes = <List<List<double>>>[[], []];
    final perClassScores = <List<double>>[[], []];

    for (int a = 0; a < n; a++) {
      final double sEmpty = out[4 * n + a];
      final double sProduct = out[5 * n + a];
      // Ultralytics default: one label per anchor (argmax over classes).
      final int cls = sProduct >= sEmpty ? AppConstants.classProduct : AppConstants.classEmpty;
      final double score = cls == AppConstants.classProduct ? sProduct : sEmpty;
      if (score < AppConstants.confidenceThreshold) continue;
      final double cx = out[a], cy = out[n + a], w = out[2 * n + a], h = out[3 * n + a];
      perClassBoxes[cls].add([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2]);
      perClassScores[cls].add(score);
    }

    List<DetectionBox> build(int cls, String label) {
      final kept = _nms(perClassBoxes[cls], perClassScores[cls], AppConstants.iouThreshold);
      return kept
          .map((i) => DetectionBox(
                rect: _toImageRect(perClassBoxes[cls][i], lb),
                classId: cls,
                label: label,
                confidence: perClassScores[cls][i],
              ))
          .where((b) => b.rect.width > 1 && b.rect.height > 1)
          .toList();
    }

    return DetectionResult(
      products: build(AppConstants.classProduct, 'product'),
      emptySpaces: build(AppConstants.classEmpty, 'empty'),
      inferenceTimeMs: inferenceMs,
    );
  }

  /// Segmentation outputs:
  ///  out0: [1, 37, 8400] = cx, cy, w, h, score(row), 32 mask coefficients
  ///  out1: [1, 32, 160, 160] prototype masks
  SegmentationResult parseSegmentationOutput(
      Float32List out0, Float32List protos, LetterboxTensor lb, double inferenceMs) {
    const int n = _numAnchors;
    final List<List<double>> boxes = [];
    final List<double> scores = [];
    final List<int> anchors = [];

    for (int a = 0; a < n; a++) {
      final double score = out0[4 * n + a];
      if (score < AppConstants.confidenceThreshold) continue;
      final double cx = out0[a], cy = out0[n + a], w = out0[2 * n + a], h = out0[3 * n + a];
      boxes.add([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2]);
      scores.add(score);
      anchors.add(a);
    }

    final List<int> kept = _nms(boxes, scores, AppConstants.iouThreshold);
    final List<SegmentedRow> rows = [];
    for (final int i in kept) {
      final coeffs = Float32List(_numMaskCoeffs);
      for (int k = 0; k < _numMaskCoeffs; k++) {
        coeffs[k] = out0[(5 + k) * n + anchors[i]];
      }
      final Rect rect = _toImageRect(boxes[i], lb);
      if (rect.width < 2 || rect.height < 2) continue;
      rows.add(SegmentedRow(
        boundingBox: rect,
        maskContour: _maskOutline(coeffs, protos, boxes[i], lb),
        confidence: scores[i],
      ));
    }
    rows.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
    return SegmentationResult(rows: rows, inferenceTimeMs: inferenceMs);
  }

  /// Builds the row mask (coeffs · protos, sigmoid > 0.5 ⇔ logit > 0) only
  /// inside the detection box (Ultralytics "crop_mask"), then traces an
  /// ordered outline: top edge left→right, bottom edge right→left.
  List<Offset> _maskOutline(Float32List coeffs, Float32List protos, List<double> box, LetterboxTensor lb) {
    const int p = _protoSize;
    const int plane = p * p;
    const double ratio = 640 / p; // 4.0
    final int x0 = (box[0] / ratio).floor().clamp(0, p - 1);
    final int x1 = (box[2] / ratio).ceil().clamp(1, p);
    final int y0 = (box[1] / ratio).floor().clamp(0, p - 1);
    final int y1 = (box[3] / ratio).ceil().clamp(1, p);

    final List<Offset> top = [];
    final List<Offset> bottom = [];
    for (int px = x0; px < x1; px += 2) {
      int minY = -1, maxY = -1;
      for (int py = y0; py < y1; py++) {
        final int base = py * p + px;
        double logit = 0;
        for (int k = 0; k < _numMaskCoeffs; k++) {
          logit += coeffs[k] * protos[k * plane + base];
        }
        if (logit > 0) {
          if (minY < 0) minY = py;
          maxY = py;
        }
      }
      if (minY < 0) continue;
      final double mx = (px + 0.5) * ratio;
      top.add(_toImagePoint(mx, minY * ratio, lb));
      bottom.add(_toImagePoint(mx, (maxY + 1) * ratio, lb));
    }
    if (top.length < 2) return const [];
    return [...top, ...bottom.reversed];
  }

  Rect _toImageRect(List<double> b, LetterboxTensor lb) => CoordinateUtils.modelBoxToDisplayRect(
      b, lb.padX, lb.padY, lb.scale, lb.origWidth, lb.origHeight,
      lb.origWidth.toDouble(), lb.origHeight.toDouble());

  Offset _toImagePoint(double mx, double my, LetterboxTensor lb) => Offset(
        ((mx - lb.padX) / lb.scale).clamp(0, lb.origWidth.toDouble()),
        ((my - lb.padY) / lb.scale).clamp(0, lb.origHeight.toDouble()),
      );
}
