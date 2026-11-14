import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../data/models/segmentation_result.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/coordinate_utils.dart';

/// Draws the overall shelf area (viewfinder-style corner brackets), each
/// segmented shelf row (mask outline) and its label/confidence.
/// Coordinates are mapped from image pixels to the view.
class ShelfSegmentationOverlay extends StatelessWidget {
  final SegmentationResult result;
  final Size imageSize;
  final BoxFit fit;

  const ShelfSegmentationOverlay({super.key, required this.result, required this.imageSize, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: RepaintBoundary(child: CustomPaint(painter: _ShelfPainter(result, imageSize, fit))),
      ),
    );
  }
}

class _ShelfPainter extends CustomPainter {
  final SegmentationResult result;
  final Size imageSize;
  final BoxFit fit;

  _ShelfPainter(this.result, this.imageSize, this.fit);

  static const Color _shelfInk = Color(0xFF2A1C00);

  @override
  void paint(Canvas canvas, Size size) {
    final mapper = ImageToViewMapper(imageSize, size, fit);
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // 1) Shelf rows: translucent mask + crisp outline
    final fill = Paint()..color = AppConstants.rowColor;
    final outline = Paint()
      ..color = AppConstants.rowBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < result.rows.length; i++) {
      final SegmentedRow row = result.rows[i];
      final Rect box = mapper.mapRect(row.boundingBox);
      final Path path = row.maskContour.length >= 3
          ? (Path()..addPolygon(row.maskContour.map(mapper.mapOffset).toList(), true))
          : (Path()..addRRect(RRect.fromRectAndRadius(box, const Radius.circular(2))));
      canvas.drawPath(path, fill);
      canvas.drawPath(path, outline);
      _label(
        canvas,
        'Row ${i + 1} · ${(row.confidence * 100).round()}%',
        Offset(box.right, box.top),
        AppConstants.rowBorderColor,
        Colors.white,
        alignRight: true,
        above: true,
      );
    }

    // 2) Overall shelf area: corner brackets, like a camera viewfinder
    final Rect? area = result.shelfArea;
    if (area != null) {
      final r = mapper.mapRect(area).deflate(1);
      _brackets(canvas, r);
      _label(
        canvas,
        'Shelf · ${result.rowCount} ${result.rowCount == 1 ? 'row' : 'rows'}',
        r.topLeft + const Offset(6, 6),
        AppConstants.shelfColor,
        _shelfInk,
      );
    }
    canvas.restore();
  }

  void _brackets(Canvas canvas, Rect r) {
    final p = Paint()
      ..color = AppConstants.shelfColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final double l = math.min(28, math.min(r.width, r.height) * 0.25);
    final path = Path()
      ..moveTo(r.left, r.top + l)
      ..lineTo(r.left, r.top)
      ..lineTo(r.left + l, r.top)
      ..moveTo(r.right - l, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.top + l)
      ..moveTo(r.right, r.bottom - l)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - l, r.bottom)
      ..moveTo(r.left + l, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.bottom - l);
    canvas.drawPath(path, p);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset anchor,
    Color bg,
    Color fg, {
    bool alignRight = false,
    bool above = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: fg,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          height: 1.1,
          fontFeatures: AppText.tabular,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final double w = tp.width + 8, h = tp.height + 4;
    final double left = alignRight ? anchor.dx - w : anchor.dx;
    double top = above ? anchor.dy - h - 2 : anchor.dy;
    if (top < 0) top = anchor.dy + 2;
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(4));
    canvas.drawRRect(rect, Paint()..color = bg.withValues(alpha: 0.92));
    tp.paint(canvas, Offset(left + 4, top + 2));
  }

  @override
  bool shouldRepaint(_ShelfPainter old) => old.result != result || old.imageSize != imageSize || old.fit != fit;
}
