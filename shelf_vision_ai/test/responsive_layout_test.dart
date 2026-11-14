import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shelf_vision_ai/core/theme/app_theme.dart';
import 'package:shelf_vision_ai/data/models/detection_result.dart';
import 'package:shelf_vision_ai/data/models/inference_frame_result.dart';
import 'package:shelf_vision_ai/data/models/segmentation_result.dart';
import 'package:shelf_vision_ai/presentation/controllers/detection_controller.dart';
import 'package:shelf_vision_ai/presentation/screens/home_screen.dart';
import 'package:shelf_vision_ai/presentation/screens/result_screen.dart';
import 'package:shelf_vision_ai/presentation/widgets/detection_summary_card.dart';

/// Renders the screens at small-phone → tablet sizes, in light and dark,
/// with large text. Any RenderFlex overflow or layout error fails the test.
const _sizes = <String, Size>{
  'small phone 320x568': Size(320, 568),
  'phone 360x800': Size(360, 800),
  'large phone 412x915': Size(412, 915),
  'tablet 800x1280': Size(800, 1280),
};

InferenceFrameResult _sampleResult() {
  DetectionBox b(double x, double y, String l, double c) => DetectionBox(
      rect: Rect.fromLTWH(x, y, 80, 120), classId: l == 'product' ? 1 : 0, label: l, confidence: c);
  return InferenceFrameResult(
    detectionResult: DetectionResult(
      products: [for (int i = 0; i < 40; i++) b(10.0 + (i % 10) * 90, 100.0 + (i ~/ 10) * 260, 'product', 0.5 + i / 100)],
      emptySpaces: [b(500, 650, 'empty', 0.41)],
      inferenceTimeMs: 182,
    ),
    segmentationResult: const SegmentationResult(rows: [
      SegmentedRow(boundingBox: Rect.fromLTWH(0, 380, 960, 30), maskContour: [], confidence: 0.62),
      SegmentedRow(boundingBox: Rect.fromLTWH(0, 900, 960, 30), maskContour: [], confidence: 0.48),
    ], inferenceTimeMs: 240),
    totalInferenceMs: 1234.5,
    fps: 9.7,
    timestamp: DateTime(2026),
    imageSize: const Size(960, 1280),
  );
}

Future<void> _pump(WidgetTester tester, Size size, ThemeData theme, Widget home,
    {Object? args, String route = '/'}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => DetectionController(), // not initialized: no camera in tests
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        onGenerateRoute: (s) => MaterialPageRoute(
          settings: RouteSettings(name: route, arguments: args),
          builder: (_) => home,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final mode in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
    for (final s in _sizes.entries) {
      testWidgets('Home lays out cleanly — ${mode.key}, ${s.key}', (tester) async {
        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.dumpErrorToConsole(details);
        };
        await _pump(tester, s.value, mode.value, const HomeScreen());
        expect(find.text('Start Live Detection'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Shelf report lays out cleanly — ${mode.key}, ${s.key}', (tester) async {
        await _pump(tester, s.value, mode.value, const ResultScreen(),
            args: {'result': _sampleResult(), 'imagePath': 'assets/images/2.jpg'});
        expect(find.text('Shelf report'), findsOneWidget);
        // Scroll through the whole report to lay out every section.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
        await tester.pump();
        expect(find.text('Run details'.toUpperCase()), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final s in _sizes.entries) {
    testWidgets('Live HUD fits — ${s.key}', (tester) async {
      await _pump(
        tester,
        s.value,
        AppTheme.dark,
        Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DetectionSummaryCard(result: _sampleResult()),
            ),
          ),
        ),
      );
      expect(find.text('Products'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
