import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_vision_ai/data/models/detection_result.dart';
import 'package:shelf_vision_ai/data/models/segmentation_result.dart';
import 'package:shelf_vision_ai/data/models/inference_frame_result.dart';
import 'package:shelf_vision_ai/presentation/widgets/detection_summary_card.dart';

void main() {
  testWidgets('DetectionSummaryCard renders product, empty, row counts and metrics', (WidgetTester tester) async {
    final mockResult = InferenceFrameResult(
      detectionResult: const DetectionResult(
        products: [
          DetectionBox(
            rect: Rect.fromLTWH(10, 10, 50, 50),
            classId: 1,
            label: 'product',
            confidence: 0.95,
          ),
        ],
        emptySpaces: [
          DetectionBox(
            rect: Rect.fromLTWH(80, 80, 40, 40),
            classId: 0,
            label: 'empty',
            confidence: 0.82,
          ),
        ],
        inferenceTimeMs: 35.0,
      ),
      segmentationResult: const SegmentationResult(
        rows: [
          SegmentedRow(
            boundingBox: Rect.fromLTWH(0, 0, 100, 20),
            maskContour: [],
            confidence: 0.77,
          ),
        ],
        inferenceTimeMs: 42.0,
      ),
      totalInferenceMs: 77.0,
      fps: 5.2,
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetectionSummaryCard(result: mockResult),
        ),
      ),
    );

    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('Rows'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(3)); // 1 product, 1 empty, 1 row
    expect(find.textContaining('5.2 fps'), findsOneWidget);
    expect(find.textContaining('77 ms'), findsOneWidget);
  });
}
