import 'package:flutter/material.dart';
import '../../data/models/detection_result.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/coordinate_utils.dart';

/// Draws product / empty-space boxes with label + confidence.
/// Box coordinates are in image pixels; [imageSize] + [fit] must match how
/// the underlying image/preview is rendered so boxes line up.
class ProductDetectionOverlay extends StatelessWidget {
  final DetectionResult result;
  final Size imageSize;
  final BoxFit fit;

  const ProductDetectionOverlay({super.key, required this.result, required this.imageSize, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: RepaintBoundary(child: CustomPaint(painter: _ProductDetectionPainter(result, imageSize, fit))),
      ),
    );
  }
}

class _ProductDetectionPainter extends CustomPainter {
  final DetectionResult result;
  final Size imageSize;
  final BoxFit fit;

  _ProductDetectionPainter(this.result, this.imageSize, this.fit);

  static const Color _productInk = Color(0xFF06210F); // dark text on green
  static const Radius _corner = Radius.circular(2.5);

  @override
  void paint(Canvas canvas, Size size) {
    final mapper = ImageToViewMapper(imageSize, size, fit);
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final productStroke = Paint()
      ..color = AppConstants.productColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final emptyStroke = Paint()
      ..color = AppConstants.emptyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final emptyFill = Paint()..color = AppConstants.emptyColor.withValues(alpha: 0.16);

    for (final DetectionBox box in result.emptySpaces) {
      final r = RRect.fromRectAndRadius(mapper.mapRect(box.rect), _corner);
      canvas.drawRRect(r, emptyFill);
      canvas.drawRRect(r, emptyStroke);
      _drawLabel(
        canvas,
        'Empty ${(box.confidence * 100).round()}%',
        r.outerRect,
        AppConstants.emptyColor,
        Colors.white,
      );
    }

    for (final DetectionBox box in result.products) {
      final r = RRect.fromRectAndRadius(mapper.mapRect(box.rect), _corner);
      canvas.drawRRect(r, productStroke);
      _drawLabel(
        canvas,
        'Product ${(box.confidence * 100).round()}%',
        r.outerRect,
        AppConstants.productColor,
        _productInk,
      );
    }
    canvas.restore();
  }

  void _drawLabel(Canvas canvas, String text, Rect box, Color bg, Color fg) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          height: 1.1,
          fontFeatures: AppText.tabular,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    // Above the box when there is room, otherwise tucked inside its top edge.
    final double h = tp.height + 3;
    final double w = tp.width + 6;
    final double top = box.top - h >= 0 ? box.top - h : box.top;
    final rect = RRect.fromLTRBAndCorners(
      box.left - 0.75,
      top,
      box.left - 0.75 + w,
      top + h,
      topLeft: _corner,
      topRight: _corner,
      bottomRight: _corner,
    );
    canvas.drawRRect(rect, Paint()..color = bg);
    tp.paint(canvas, Offset(rect.left + 3, top + 1.5));
  }

  @override
  bool shouldRepaint(_ProductDetectionPainter old) =>
      old.result != result || old.imageSize != imageSize || old.fit != fit;
}
