import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/inference_frame_result.dart';

/// Compact live HUD. Each metric's dot matches its overlay colour, so the bar
/// doubles as the legend for what is drawn on the camera.
class DetectionSummaryCard extends StatelessWidget {
  final InferenceFrameResult result;

  const DetectionSummaryCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final det = result.detectionResult;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                _Metric(value: det.productCount, label: 'Products', color: AppColors.product),
                const _Separator(),
                _Metric(value: det.emptyCount, label: 'Empty', color: AppColors.empty),
                const _Separator(),
                _Metric(value: result.segmentationResult.rowCount, label: 'Rows', color: AppColors.row),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${result.fps.toStringAsFixed(1)} fps  ·  ${result.totalInferenceMs.toStringAsFixed(0)} ms per frame',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11.5,
              fontFeatures: AppText.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _Metric({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: AppText.metric.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          // Scales down (never overflows) on narrow phones / large text sizes.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) =>
      VerticalDivider(width: 1, thickness: 1, indent: 4, endIndent: 4, color: Colors.white.withValues(alpha: 0.1));
}
