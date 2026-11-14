import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../controllers/detection_controller.dart';
import '../widgets/detection_summary_card.dart';
import '../widgets/product_detection_overlay.dart';
import '../widgets/shelf_segmentation_overlay.dart';
import '../widgets/ui_kit.dart';

class LiveDetectionScreen extends StatefulWidget {
  const LiveDetectionScreen({super.key});

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  bool _isDetecting = false;
  // Cached in initState: looking up providers in dispose() is unsafe
  // (deactivated element) and asserts in debug builds.
  late final DetectionController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = context.read<DetectionController>();
    // Start after the first frame so the controller is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _ctrl.startLiveDetection();
        setState(() => _isDetecting = _ctrl.isDetecting);
      });
    });
  }

  @override
  void dispose() {
    // Defer so we don't notify listeners while the widget tree is locked.
    final ctrl = _ctrl;
    Future.microtask(ctrl.stopLiveDetection);
    super.dispose();
  }

  void _toggleDetection(DetectionController ctrl) {
    HapticFeedback.mediumImpact();
    if (_isDetecting) {
      ctrl.stopLiveDetection();
    } else {
      ctrl.startLiveDetection();
    }
    setState(() => _isDetecting = !_isDetecting);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyle.copyWith(systemNavigationBarColor: Colors.black),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<DetectionController>(
          builder: (context, controller, _) {
            final camCtrl = controller.cameraService.controller;
            final hasCamera = camCtrl != null && camCtrl.value.isInitialized;
            final result = controller.lastResult;
            final showResult = result != null && _isDetecting;

            String? hint;
            if (_isDetecting && result == null) {
              hint = 'Point the camera at a shelf';
            } else if (showResult &&
                result.detectionResult.productCount == 0 &&
                result.segmentationResult.rowCount == 0) {
              hint = 'No shelf in view';
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview — full bleed
                if (hasCamera)
                  _FullScreenCameraPreview(controller: camCtrl)
                else
                  const Center(
                    child: Text('Camera unavailable', style: TextStyle(color: AppColors.textSecondary)),
                  ),

                // Overlays — preview is BoxFit.cover, so overlays use cover mapping too.
                if (showResult)
                  ShelfSegmentationOverlay(
                    result: result.segmentationResult,
                    imageSize: result.imageSize,
                    fit: BoxFit.cover,
                  ),
                if (showResult)
                  ProductDetectionOverlay(
                    result: result.detectionResult,
                    imageSize: result.imageSize,
                    fit: BoxFit.cover,
                  ),

                // Scrims keep chrome legible over bright shelves
                const Align(alignment: Alignment.topCenter, child: CameraScrim(top: true, height: 120)),
                const Align(alignment: Alignment.bottomCenter, child: CameraScrim(top: false, height: 260)),

                // Top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                      child: Row(
                        children: [
                          CameraChromeButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          CameraPill(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusDot(
                                  color: _isDetecting ? AppColors.empty : Colors.white54,
                                  size: 7,
                                  pulse: _isDetecting,
                                ),
                                const SizedBox(width: 7),
                                Text(_isDetecting ? 'Live' : 'Paused'),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 40), // balances the back button
                        ],
                      ),
                    ),
                  ),
                ),

                // Error / guidance
                Positioned(
                  top: 0,
                  left: AppSpacing.gutter,
                  right: AppSpacing.gutter,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: ResponsiveCenter(
                        maxWidth: Breakpoints.controls,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: controller.error != null
                              ? _ErrorBanner(key: const ValueKey('err'), message: controller.error!)
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
                if (hint != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      child: CameraPill(
                        child: Flexible(child: Text(hint, overflow: TextOverflow.ellipsis)),
                      ),
                    ),
                  ),

                // Bottom: HUD + control
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: ResponsiveCenter(
                        maxWidth: Breakpoints.controls,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              child: showResult
                                  ? Padding(
                                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                                      child: DetectionSummaryCard(result: result),
                                    )
                                  : const SizedBox(width: double.infinity),
                            ),
                            _PauseButton(detecting: _isDetecting, onPressed: () => _toggleDetection(controller)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _FullScreenCameraPreview extends StatelessWidget {
  final CameraController controller;
  const _FullScreenCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
  }
}

/// Shutter-style round control: pause while live, resume while paused.
class _PauseButton extends StatelessWidget {
  final bool detecting;
  final VoidCallback onPressed;
  const _PauseButton({required this.detecting, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: detecting ? 'Pause detection' : 'Resume detection',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 68,
          height: 68,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: detecting ? Colors.white.withValues(alpha: 0.18) : Colors.white,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Icon(
                detecting ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(detecting),
                color: detecting ? Colors.white : Colors.black,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE62A1416),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.replaceFirst('Exception: ', ''),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
