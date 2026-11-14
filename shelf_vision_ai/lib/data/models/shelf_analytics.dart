import 'detection_result.dart';
import 'inference_frame_result.dart';

/// Per-shelf-row stock statistics: every product / empty-space box is assigned
/// to the shelf row it belongs to (by vertical position), then
/// empty% = emptyArea / (emptyArea + productArea) × 100.
class ShelfRowStats {
  final int rowNumber; // 1-based, top to bottom
  int products = 0;
  int emptySlots = 0;
  double productArea = 0;
  double emptyArea = 0;
  ShelfRowStats(this.rowNumber);

  double get emptyPercent {
    final total = productArea + emptyArea;
    return total > 0 ? emptyArea / total * 100 : 0;
  }

  bool get needsRestock => emptyPercent >= ShelfAnalytics.restockThresholdPercent;
}

class ShelfAnalytics {
  static const double restockThresholdPercent = 30;

  final List<ShelfRowStats> rows;
  final int unassigned; // detections when no shelf rows were found
  const ShelfAnalytics(this.rows, this.unassigned);

  factory ShelfAnalytics.fromResult(InferenceFrameResult r) {
    final segRows = r.segmentationResult.rows; // already sorted top → bottom
    final stats = List.generate(segRows.length, (i) => ShelfRowStats(i + 1));
    int unassigned = 0;

    int rowFor(DetectionBox b) {
      if (segRows.isEmpty) return -1;
      final cy = b.rect.center.dy;
      int best = 0;
      double bestDist = double.infinity;
      for (int i = 0; i < segRows.length; i++) {
        final box = segRows[i].boundingBox;
        if (cy >= box.top && cy <= box.bottom) return i;
        final d = (box.center.dy - cy).abs();
        if (d < bestDist) {
          bestDist = d;
          best = i;
        }
      }
      return best;
    }

    for (final b in r.detectionResult.all) {
      final i = rowFor(b);
      if (i < 0) {
        unassigned++;
        continue;
      }
      final area = b.rect.width * b.rect.height;
      if (b.label == 'product') {
        stats[i].products++;
        stats[i].productArea += area;
      } else {
        stats[i].emptySlots++;
        stats[i].emptyArea += area;
      }
    }
    return ShelfAnalytics(stats, unassigned);
  }

  double get overallEmptyPercent {
    double p = 0, e = 0;
    for (final s in rows) {
      p += s.productArea;
      e += s.emptyArea;
    }
    return p + e > 0 ? e / (p + e) * 100 : 0;
  }
}
