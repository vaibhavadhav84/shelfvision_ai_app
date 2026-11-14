import 'package:flutter/material.dart';

/// One shelf row produced by the YOLO11-seg model.
/// All coordinates are in ORIGINAL image pixel space (after rotation).
class SegmentedRow {
  final Rect boundingBox;

  /// Ordered outline of the row mask (top edge left→right, then bottom edge
  /// right→left), so it can be drawn directly as a closed polygon.
  final List<Offset> maskContour;
  final double confidence;
  const SegmentedRow({required this.boundingBox, required this.maskContour, required this.confidence});
}

class SegmentationResult {
  final List<SegmentedRow> rows;
  final double inferenceTimeMs;
  const SegmentationResult({required this.rows, required this.inferenceTimeMs});
  int get rowCount => rows.length;

  /// Overall shelf area = union of all detected shelf rows (null if none).
  Rect? get shelfArea {
    if (rows.isEmpty) return null;
    Rect area = rows.first.boundingBox;
    for (final r in rows.skip(1)) {
      area = area.expandToInclude(r.boundingBox);
    }
    return area;
  }
}
