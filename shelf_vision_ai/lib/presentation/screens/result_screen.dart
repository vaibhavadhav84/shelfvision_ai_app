import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/detection_result.dart';
import '../../data/models/inference_frame_result.dart';
import '../../data/models/segmentation_result.dart';
import '../../data/models/shelf_analytics.dart';
import '../widgets/product_detection_overlay.dart';
import '../widgets/shelf_segmentation_overlay.dart';
import '../widgets/ui_kit.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showProducts = true;
  bool _showEmpty = true;
  bool _showRows = true;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args == null || args['result'] == null || args['imagePath'] == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shelf report')),
        body: Center(child: Text('Nothing to show yet.', style: context.text.bodyMuted)),
      );
    }

    final InferenceFrameResult result = args['result'] as InferenceFrameResult;
    final File file = File(args['imagePath'] as String);
    final det = result.detectionResult;
    final seg = result.segmentationResult;
    final analytics = ShelfAnalytics.fromResult(result);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelf report'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pageGutter(context), AppSpacing.xs, pageGutter(context), AppSpacing.xxl),
          child: ResponsiveCenter(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AnnotatedImage(
                  file: file,
                  result: result,
                  showProducts: _showProducts,
                  showEmpty: _showEmpty,
                  showRows: _showRows,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _LayerChip(
                      label: 'Products',
                      count: det.productCount,
                      color: AppColors.product,
                      selected: _showProducts,
                      onTap: () => setState(() => _showProducts = !_showProducts),
                    ),
                    _LayerChip(
                      label: 'Empty',
                      count: det.emptyCount,
                      color: AppColors.empty,
                      selected: _showEmpty,
                      onTap: () => setState(() => _showEmpty = !_showEmpty),
                    ),
                    _LayerChip(
                      label: 'Shelf rows',
                      count: seg.rowCount,
                      color: AppColors.row,
                      selected: _showRows,
                      onTap: () => setState(() => _showRows = !_showRows),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Key numbers — one strip, not four cards
                _SummaryStrip(
                  items: [
                    ('${det.productCount}', 'Products'),
                    ('${det.emptyCount}', 'Empty gaps'),
                    ('${seg.rowCount}', 'Shelf rows'),
                    ('${analytics.overallEmptyPercent.toStringAsFixed(0)}%', 'Empty area'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),

                const SectionLabel('Stock by shelf row'),
                if (analytics.rows.isEmpty)
                  const _EmptyNote('No shelf rows were found. Try a straighter, wider shot of the shelf.')
                else
                  GroupedSection(children: [for (final s in analytics.rows) _RowStockTile(stats: s)]),
                const SizedBox(height: AppSpacing.xxl),

                SectionLabel('Detections', trailing: Text('conf ≥ 25%', style: context.text.caption)),
                GroupedSection(
                  children: [
                    _ConfidenceTile(label: 'Products', color: AppColors.product, boxes: det.products),
                    _ConfidenceTile(label: 'Empty gaps', color: AppColors.empty, boxes: det.emptySpaces),
                    _ConfidenceTile(
                      label: 'Shelf rows',
                      color: AppColors.row,
                      confidences: seg.rows.map((r) => r.confidence).toList(),
                    ),
                    if (det.all.isNotEmpty) _AllDetectionsTile(boxes: det.all),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),

                const SectionLabel('Run details'),
                GroupedSection(
                  children: [
                    _KeyValue('Total time', '${result.totalInferenceMs.toStringAsFixed(0)} ms'),
                    _KeyValue('Product detector', '${det.inferenceTimeMs.toStringAsFixed(0)} ms'),
                    _KeyValue('Shelf segmenter', '${seg.inferenceTimeMs.toStringAsFixed(0)} ms'),
                    _KeyValue(
                      'Analyzed at',
                      '${result.imageSize.width.toStringAsFixed(0)} × ${result.imageSize.height.toStringAsFixed(0)} px',
                    ),
                    const _KeyValue('Models', 'YOLO11n · YOLO11n-seg'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _AnnotatedImage extends StatelessWidget {
  final File file;
  final InferenceFrameResult result;
  final bool showProducts, showEmpty, showRows;
  const _AnnotatedImage({
    required this.file,
    required this.result,
    required this.showProducts,
    required this.showEmpty,
    required this.showRows,
  });

  @override
  Widget build(BuildContext context) {
    final det = result.detectionResult;
    final size = result.imageSize;
    final maxH = MediaQuery.sizeOf(context).height * 0.52;
    final aspect = size.height > 0 ? size.width / size.height : 1.0;

    return LayoutBuilder(
      builder: (context, c) {
        // Fit the frame to the photo's own aspect ratio (no letterbox bars).
        final w = math.min(c.maxWidth, maxH * aspect);
        final h = w / aspect;
        return Center(
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: context.palette.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(file, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
                ShelfSegmentationOverlay(
                  result: showRows
                      ? result.segmentationResult
                      : SegmentationResult(rows: const [], inferenceTimeMs: result.segmentationResult.inferenceTimeMs),
                  imageSize: size,
                  fit: BoxFit.contain,
                ),
                ProductDetectionOverlay(
                  result: DetectionResult(
                    products: showProducts ? det.products : const [],
                    emptySpaces: showEmpty ? det.emptySpaces : const [],
                    inferenceTimeMs: det.inferenceTimeMs,
                  ),
                  imageSize: size,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Legend entry that also toggles its overlay layer.
class _LayerChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _LayerChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: selected,
      button: true,
      label: '$label layer',
      child: Material(
        color: selected ? context.palette.surfaceRaised : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: selected ? context.palette.hairline : context.palette.hairline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: selected ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected ? color : Colors.transparent,
                      border: Border.all(color: color, width: 1.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(label, style: TextStyle(fontSize: 13, color: context.palette.textPrimary)),
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(fontSize: 13, color: context.palette.textTertiary, fontFeatures: AppText.tabular),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final List<(String, String)> items;
  const _SummaryStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) children.add(const VerticalDivider(width: 1, indent: 2, endIndent: 2));
      children.add(
        Expanded(
          child: Column(
            children: [
              Text(items[i].$1, style: context.text.metric),
              const SizedBox(height: 4),
              Text(items[i].$2, style: context.text.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.palette.hairline),
      ),
      child: IntrinsicHeight(child: Row(children: children)),
    );
  }
}

class _RowStockTile extends StatelessWidget {
  final ShelfRowStats stats;
  const _RowStockTile({required this.stats});

  @override
  Widget build(BuildContext context) {
    final emptyPct = stats.emptyPercent;
    final restock = stats.needsRestock;
    final barColor = restock ? AppColors.danger : AppColors.product;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 14, AppSpacing.lg, 14),
      child: Column(
        children: [
          Row(
            children: [
              Text('Row ${stats.rowNumber}', style: context.text.body.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '${stats.products} products · ${stats.emptySlots} empty',
                  style: context.text.caption.copyWith(
                    color: context.palette.textSecondary,
                    fontFeatures: AppText.tabular,
                  ),
                ),
              ),
              if (restock)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Restock',
                    style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              else
                Text(
                  '${emptyPct.toStringAsFixed(0)}% empty',
                  style: context.text.caption.copyWith(fontFeatures: AppText.tabular),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Stock level bar (filled = stocked share of the row)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (100 - emptyPct) / 100,
              minHeight: 4,
              backgroundColor: context.palette.surfaceRaised,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceTile extends StatelessWidget {
  final String label;
  final Color color;
  final List<double> confidences;

  _ConfidenceTile({required this.label, required this.color, List<DetectionBox>? boxes, List<double>? confidences})
    : confidences = confidences ?? boxes!.map((b) => b.confidence).toList();

  @override
  Widget build(BuildContext context) {
    final n = confidences.length;
    final String detail;
    if (n == 0) {
      detail = 'None found';
    } else {
      final avg = confidences.reduce((a, b) => a + b) / n * 100;
      final lo = confidences.reduce(math.min) * 100;
      final hi = confidences.reduce(math.max) * 100;
      detail = 'avg ${avg.toStringAsFixed(0)}%  ·  ${lo.toStringAsFixed(0)}–${hi.toStringAsFixed(0)}%';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: context.text.body.copyWith(fontSize: 14.5))),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              detail,
              textAlign: TextAlign.end,
              style: context.text.caption.copyWith(color: context.palette.textSecondary, fontFeatures: AppText.tabular),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDetectionsTile extends StatelessWidget {
  final List<DetectionBox> boxes;
  const _AllDetectionsTile({required this.boxes});

  @override
  Widget build(BuildContext context) {
    final sorted = [...boxes]..sort((a, b) => b.confidence.compareTo(a.confidence));
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        iconColor: context.palette.textSecondary,
        collapsedIconColor: context.palette.textTertiary,
        title: Text('All detections', style: context.text.body.copyWith(fontSize: 14.5, color: context.palette.accent)),
        trailing: Text('${boxes.length}', style: context.text.caption.copyWith(fontFeatures: AppText.tabular)),
        children: [
          for (int i = 0; i < sorted.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}', style: context.text.caption.copyWith(fontFeatures: AppText.tabular)),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: sorted[i].label == 'product' ? AppColors.product : AppColors.empty,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sorted[i].label == 'product' ? 'Product' : 'Empty gap',
                      style: TextStyle(fontSize: 13.5, color: context.palette.textPrimary),
                    ),
                  ),
                  Text(
                    '${(sorted[i].confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 13, color: context.palette.textSecondary, fontFeatures: AppText.tabular),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String k;
  final String v;
  const _KeyValue(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 13),
      child: Row(
        children: [
          Expanded(child: Text(k, style: context.text.bodyMuted.copyWith(fontSize: 14))),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: context.text.body.copyWith(fontSize: 14, fontFeatures: AppText.tabular),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.palette.hairline),
      ),
      child: Text(text, style: context.text.bodyMuted.copyWith(fontSize: 13.5)),
    );
  }
}
