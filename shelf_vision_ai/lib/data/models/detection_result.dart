import 'package:flutter/material.dart';

class DetectionBox {
  final Rect rect;
  final int classId;
  final String label;
  final double confidence;
  const DetectionBox({required this.rect, required this.classId, required this.label, required this.confidence});
}

class DetectionResult {
  final List<DetectionBox> products;
  final List<DetectionBox> emptySpaces;
  final double inferenceTimeMs;
  const DetectionResult({required this.products, required this.emptySpaces, required this.inferenceTimeMs});
  int get productCount => products.length;
  int get emptyCount => emptySpaces.length;
  List<DetectionBox> get all => [...products, ...emptySpaces];
}
