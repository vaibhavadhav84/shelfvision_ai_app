import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../controllers/detection_controller.dart';
import '../widgets/ui_kit.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostPick());
  }

  /// Android may kill the app while the system photo picker is open (low
  /// memory). image_picker keeps the chosen photo; resume the user's flow.
  Future<void> _recoverLostPick() async {
    if (!Platform.isAndroid) return;
    try {
      final LostDataResponse lost = await ImagePicker().retrieveLostData();
      final path = lost.file?.path;
      if (path == null || !mounted) return;
      Navigator.pushNamed(
        context,
        '/capture',
        arguments: {'recoveredImagePath': path},
      );
    } catch (_) {
      // Nothing to recover.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ShelfVision AI'), centerTitle: true),
      body: Consumer<DetectionController>(
        builder: (context, controller, _) {
          final gutter = pageGutter(context);
          return SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: gutter,
                    vertical: AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (AppSpacing.lg * 2),
                    ),
                    child: IntrinsicHeight(
                      child: ResponsiveCenter(
                        maxWidth: 520,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeroSection(context),
                            const SizedBox(height: AppSpacing.md),
                            _buildStatusCards(context, controller),
                            const SizedBox(height: AppSpacing.md),
                            _buildCapabilitiesCard(context),
                            const Spacer(),
                            _buildActionButtons(context, controller),
                            const SizedBox(height: AppSpacing.sm),
                            _buildFooter(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Capabilities overview card
  // ---------------------------------------------------------------------------

  Widget _buildCapabilitiesCard(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 4,
              right: 4,
              bottom: AppSpacing.md,
              top: 2,
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: p.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI DETECTION CAPABILITIES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: p.textSecondary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '2 Models Active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: p.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _featureTile(
            context,
            icon: Icons.inventory_2_outlined,
            color: AppColors.product,
            title: 'Product Detection',
            subtitle: 'Detects shelf items with bounding boxes',
            badge: 'Model A',
          ),
          const SizedBox(height: 10),
          _featureTile(
            context,
            icon: Icons.check_box_outline_blank,
            color: AppColors.empty,
            title: 'Empty Space Alert',
            subtitle: 'Flags out-of-stock gaps in real-time',
            badge: 'Model A',
          ),
          const SizedBox(height: 10),
          _featureTile(
            context,
            icon: Icons.table_rows_outlined,
            color: AppColors.row,
            title: 'Shelf Row Segmentation',
            subtitle: 'Segments shelf rows with polygon masks',
            badge: 'Model B',
          ),
        ],
      ),
    );
  }

  Widget _featureTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String badge,
  }) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: p.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero section
  // ---------------------------------------------------------------------------

  Widget _buildHeroSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1DE9B6).withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'ShelfVision AI',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Real-time shelf detection powered by YOLO11',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.secondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Status cards
  // ---------------------------------------------------------------------------

  Widget _buildStatusCards(
    BuildContext context,
    DetectionController controller,
  ) {
    // Equal-width cards that share the row (never overflow on narrow phones),
    // stretched to the same height even when a label wraps.
    final pending = controller.isLoading;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatusCard(
              label: 'Camera',
              isOk: controller.cameraPermissionGranted,
              pending: pending,
              okText: 'Granted',
              failText: 'Denied',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatusCard(
              label: 'Model A\n(Detection)',
              isOk: controller.modelLoaded,
              pending: pending,
              okText: 'Loaded',
              failText: 'Not loaded',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatusCard(
              label: 'Model B\n(Segmentation)',
              isOk: controller.modelLoaded,
              pending: pending,
              okText: 'Loaded',
              failText: 'Not loaded',
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action buttons
  // ---------------------------------------------------------------------------

  Widget _buildActionButtons(
    BuildContext context,
    DetectionController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: controller.isLoading
              ? null
              : () => Navigator.pushNamed(context, '/live'),
          icon: const Icon(Icons.videocam),
          label: const Text('Start Live Detection'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: controller.isLoading
              ? null
              : () => Navigator.pushNamed(context, '/capture'),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Capture Shelf Image'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (controller.isLoading) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        if (controller.error != null) ...[
          const SizedBox(height: 12),
          Text(
            controller.error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Footer
  // ---------------------------------------------------------------------------

  Widget _buildFooter(BuildContext context) {
    return Text(
      'Using YOLO11n + YOLO11n-seg | ONNX Runtime',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
// Status card widget
// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  final String label;
  final bool isOk;
  final bool pending;
  final String okText;
  final String failText;

  const _StatusCard({
    required this.label,
    required this.isOk,
    required this.okText,
    required this.failText,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color color = pending
        ? AppColors.warning
        : (isOk ? AppColors.product : AppColors.danger);
    final String status = pending ? 'Loading' : (isOk ? okText : failText);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: pending
                  ? SizedBox(
                      key: const ValueKey('p'),
                      width: 26,
                      height: 26,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: color,
                        ),
                      ),
                    )
                  : Icon(
                      isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      key: ValueKey(isOk),
                      color: color,
                      size: 26,
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: p.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              status,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
