import 'dart:math' as math;

import 'package:flutter/material.dart';

class CoordinateUtils {
  static Offset modelToImageCoords(double mx, double my, double padX, double padY, double scale) {
    return Offset((mx - padX) / scale, (my - padY) / scale);
  }

  // box = [x1, y1, x2, y2] in model (640x640) space
  static Rect modelBoxToDisplayRect(List<double> box, double padX, double padY, double scale,
      int origW, int origH, double previewW, double previewH) {
    final double x1Img = ((box[0] - padX) / scale).clamp(0, origW.toDouble());
    final double y1Img = ((box[1] - padY) / scale).clamp(0, origH.toDouble());
    final double x2Img = ((box[2] - padX) / scale).clamp(0, origW.toDouble());
    final double y2Img = ((box[3] - padY) / scale).clamp(0, origH.toDouble());
    final double scaleX = previewW / origW;
    final double scaleY = previewH / origH;
    return Rect.fromLTRB(x1Img * scaleX, y1Img * scaleY, x2Img * scaleX, y2Img * scaleY);
  }

  static Rect scaleRect(Rect rect, double scaleX, double scaleY) =>
    Rect.fromLTRB(rect.left * scaleX, rect.top * scaleY, rect.right * scaleX, rect.bottom * scaleY);

  static Rect clipRect(Rect rect, double maxW, double maxH) =>
    Rect.fromLTRB(rect.left.clamp(0, maxW), rect.top.clamp(0, maxH),
                  rect.right.clamp(0, maxW), rect.bottom.clamp(0, maxH));

  static double iou(Rect a, Rect b) {
    final Rect inter = a.intersect(b);
    if (inter.isEmpty) return 0;
    final double interArea = inter.width * inter.height;
    final double unionArea = a.width * a.height + b.width * b.height - interArea;
    return unionArea > 0 ? interArea / unionArea : 0;
  }
}

/// Maps image-pixel coordinates onto a widget of [viewSize] where the image
/// is rendered with [fit] (BoxFit.cover for the live preview, BoxFit.contain
/// for still images). Keeps overlays aligned with what the user sees.
class ImageToViewMapper {
  final double scale;
  final double dx;
  final double dy;

  ImageToViewMapper._(this.scale, this.dx, this.dy);

  factory ImageToViewMapper(Size imageSize, Size viewSize, BoxFit fit) {
    if (imageSize.isEmpty || viewSize.isEmpty) return ImageToViewMapper._(1, 0, 0);
    final sx = viewSize.width / imageSize.width;
    final sy = viewSize.height / imageSize.height;
    final s = fit == BoxFit.cover ? math.max(sx, sy) : math.min(sx, sy);
    return ImageToViewMapper._(
      s,
      (viewSize.width - imageSize.width * s) / 2,
      (viewSize.height - imageSize.height * s) / 2,
    );
  }

  Offset mapOffset(Offset p) => Offset(p.dx * scale + dx, p.dy * scale + dy);

  Rect mapRect(Rect r) => Rect.fromLTRB(
        r.left * scale + dx,
        r.top * scale + dy,
        r.right * scale + dx,
        r.bottom * scale + dy,
      );
}
