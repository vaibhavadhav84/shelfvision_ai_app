import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';

/// Result of YOLO letterbox preprocessing.
class LetterboxTensor {
  final Float32List tensor; // NCHW [1,3,size,size], RGB, 0..1
  final double padX;
  final double padY;
  final double scale;
  final int origWidth; // width of the (rotated) source image
  final int origHeight;
  const LetterboxTensor(this.tensor, this.padX, this.padY, this.scale, this.origWidth, this.origHeight);
}

/// Plain, isolate-sendable copy of a YUV420 camera frame.
class YuvFrame {
  final int width;
  final int height;
  final Uint8List y, u, v;
  final int yRowStride, uvRowStride, uvPixelStride;
  const YuvFrame({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });

  factory YuvFrame.fromCameraImage(CameraImage image) {
    if (image.planes.length < 3) {
      throw Exception('Expected YUV420 frame with 3 planes, got ${image.planes.length}');
    }
    final p = image.planes;
    return YuvFrame(
      width: image.width,
      height: image.height,
      y: Uint8List.fromList(p[0].bytes),
      u: Uint8List.fromList(p[1].bytes),
      v: Uint8List.fromList(p[2].bytes),
      yRowStride: p[0].bytesPerRow,
      uvRowStride: p[1].bytesPerRow,
      uvPixelStride: p[1].bytesPerPixel ?? 1,
    );
  }
}

class ImageUtils {
  static const double _padValue = 114 / 255.0;

  /// Single pass: YUV420 → RGB → rotate(sensorOrientation) → letterbox(size)
  /// → normalized NCHW float tensor. Nearest-neighbour sampling, respects the
  /// row/pixel strides of every plane (row padding is common on Android).
  static LetterboxTensor yuvToLetterboxTensor(YuvFrame f, int rotation, int size) {
    final bool swap = rotation == 90 || rotation == 270;
    final int rotW = swap ? f.height : f.width;
    final int rotH = swap ? f.width : f.height;
    final double scale = size / (rotW > rotH ? rotW : rotH);
    final int newW = (rotW * scale).round();
    final int newH = (rotH * scale).round();
    final int padX = ((size - newW) / 2).round();
    final int padY = ((size - newH) / 2).round();

    final int plane = size * size;
    final Float32List out = Float32List(3 * plane)..fillRange(0, 3 * plane, _padValue);
    final int srcW = f.width, srcH = f.height;

    for (int oy = 0; oy < newH; oy++) {
      int ry = ((oy + 0.5) / scale).floor();
      if (ry >= rotH) ry = rotH - 1;
      final int rowBase = (oy + padY) * size + padX;
      for (int ox = 0; ox < newW; ox++) {
        int rx = ((ox + 0.5) / scale).floor();
        if (rx >= rotW) rx = rotW - 1;
        int sx, sy;
        switch (rotation) {
          case 90:
            sx = ry;
            sy = srcH - 1 - rx;
            break;
          case 180:
            sx = srcW - 1 - rx;
            sy = srcH - 1 - ry;
            break;
          case 270:
            sx = srcW - 1 - ry;
            sy = rx;
            break;
          default:
            sx = rx;
            sy = ry;
        }
        final int yv = f.y[sy * f.yRowStride + sx];
        final int uvIdx = (sy >> 1) * f.uvRowStride + (sx >> 1) * f.uvPixelStride;
        final int uv = f.u[uvIdx] - 128;
        final int vv = f.v[uvIdx] - 128;
        final double r = (yv + 1.370705 * vv).clamp(0, 255).toDouble();
        final double g = (yv - 0.698001 * vv - 0.337633 * uv).clamp(0, 255).toDouble();
        final double b = (yv + 1.732446 * uv).clamp(0, 255).toDouble();
        final int idx = rowBase + ox;
        out[idx] = r / 255.0;
        out[plane + idx] = g / 255.0;
        out[2 * plane + idx] = b / 255.0;
      }
    }
    return LetterboxTensor(out, padX.toDouble(), padY.toDouble(), scale, rotW, rotH);
  }

  /// Letterbox a decoded still image into a normalized NCHW tensor.
  static LetterboxTensor imageToLetterboxTensor(img.Image image, int size) {
    final Map<String, dynamic> lb = letterboxResize(image, size);
    return LetterboxTensor(
      imageToFloat32List(lb['image'] as img.Image),
      lb['padX'] as double,
      lb['padY'] as double,
      lb['scale'] as double,
      image.width,
      image.height,
    );
  }

  // Resize with letterbox padding (gray 114,114,114), maintain aspect ratio
  static Map<String, dynamic> letterboxResize(img.Image image, int targetSize) {
    final double scale = targetSize / (image.width > image.height ? image.width : image.height);
    final int newW = (image.width * scale).round();
    final int newH = (image.height * scale).round();
    final img.Image resized = img.copyResize(image, width: newW, height: newH,
        interpolation: img.Interpolation.average);
    final img.Image canvas = img.Image(width: targetSize, height: targetSize);
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));
    final int padX = ((targetSize - newW) / 2).round();
    final int padY = ((targetSize - newH) / 2).round();
    img.compositeImage(canvas, resized, dstX: padX, dstY: padY);
    return {'image': canvas, 'padX': padX.toDouble(), 'padY': padY.toDouble(), 'scale': scale};
  }

  // Convert img.Image to Float32List in NCHW format, normalized 0-1
  static Float32List imageToFloat32List(img.Image image) {
    final int size = image.width * image.height;
    final Float32List result = Float32List(3 * size);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final img.Pixel pixel = image.getPixel(x, y);
        final int idx = y * image.width + x;
        result[idx] = pixel.r / 255.0;             // R channel
        result[size + idx] = pixel.g / 255.0;       // G channel
        result[size * 2 + idx] = pixel.b / 255.0;  // B channel
      }
    }
    return result;
  }
}
