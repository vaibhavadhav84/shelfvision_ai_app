import 'package:flutter/material.dart';

class AppConstants {
  static const String modelDetect = 'assets/models/detect_product_empty_space.onnx';
  static const String modelSegment = 'assets/models/segment_shelf_rows.onnx';
  static const String detectLabels = 'assets/labels/detection_labels.txt';
  static const String segmentLabels = 'assets/labels/segmentation_labels.txt';
  static const int inputSize = 640;
  static const double confidenceThreshold = 0.25;
  static const double iouThreshold = 0.45;
  static const int classEmpty = 0;
  static const int classProduct = 1;
  static const int classRow = 0;
  // Overlay colours — kept in sync with AppColors semantic tokens.
  static const Color productColor = Color(0xFF3CCB7F);
  static const Color emptyColor = Color(0xFFF2585C);
  static const Color rowColor = Color(0x405B9BFF);
  static const Color rowBorderColor = Color(0xFF5B9BFF);
  static const Color shelfColor = Color(0xFFF4B740);
  static const int targetFps = 10; // upper cap; busy frames are dropped
  static const String appName = 'ShelfVision AI';
}
