import 'dart:io';
import 'package:image/image.dart' as img;
import '../../core/constants/app_constants.dart';
import '../../core/utils/image_utils.dart';

/// YOLO11 input: [1, 3, 640, 640] float32, RGB, 0..1, letterboxed with gray 114.
class ModelPreprocessingService {
  /// Live camera frame (YUV420) → rotated to portrait → letterboxed tensor.
  LetterboxTensor preprocessYuvFrame(YuvFrame frame, int sensorOrientation) =>
      ImageUtils.yuvToLetterboxTensor(frame, sensorOrientation, AppConstants.inputSize);

  /// Captured photo / gallery image → EXIF-corrected → letterboxed tensor.
  LetterboxTensor preprocessImageFile(String path) {
    final img.Image? decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) throw Exception('Failed to decode image file');
    // Camera JPEGs often store rotation in EXIF; Image.file applies it, so we must too.
    img.Image image = img.bakeOrientation(decoded);
    // Large photos (12MP+) are downscaled first: the model sees 640px anyway.
    // Area-average (anti-aliased) resize — nearest-neighbour on a 4032px photo
    // aliases badly and measurably lowers shelf-row confidence.
    const int maxSide = 1280;
    if (image.width > maxSide || image.height > maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
          : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
    }
    return ImageUtils.imageToLetterboxTensor(image, AppConstants.inputSize);
  }
}
