import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../controllers/detection_controller.dart';
import '../widgets/ui_kit.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  XFile? _capturedImage;
  bool _isProcessing = false;
  bool _isRecording = false;
  String? _recordedVideoPath;
  final ImagePicker _picker = ImagePicker();
  bool _fromGallery = false;
  String? _lastThumbnailPath; // last captured / uploaded photo for the gallery thumb

  // Recording timer + shutter flash
  Timer? _recTimer;
  Duration _recElapsed = Duration.zero;
  bool _flash = false;

  @override
  void dispose() {
    _recTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyle.copyWith(systemNavigationBarColor: Colors.black),
      child: PopScope(
        // Back from the review step returns to the camera instead of leaving.
        canPop: _capturedImage == null || _isProcessing,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_isProcessing) setState(() => _capturedImage = null);
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Consumer<DetectionController>(
            builder: (context, controller, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _capturedImage != null ? _buildReview(controller) : _buildCamera(controller),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Camera mode
  // ---------------------------------------------------------------------------

  Widget _buildCamera(DetectionController controller) {
    final camCtrl = controller.cameraService.controller;
    final ready = camCtrl != null && camCtrl.value.isInitialized;

    return SafeArea(
      key: const ValueKey('camera'),
      child: Column(
        children: [
          // Top bar
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  CameraChromeButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onPressed: _isRecording ? null : () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isRecording
                        ? CameraPill(
                            key: const ValueKey('rec'),
                            color: AppColors.danger.withValues(alpha: 0.9),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const StatusDot(color: Colors.white, size: 7, pulse: true),
                                const SizedBox(width: 7),
                                Text(_formatDuration(_recElapsed)),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  if (_recordedVideoPath != null && !_isRecording)
                    CameraChromeButton(
                      icon: Icons.video_library_outlined,
                      tooltip: 'Last video',
                      onPressed: () => _showSnack('Video saved to ${_recordedVideoPath!}'),
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),
          ),

          // Preview at its true aspect ratio — what you see is what you capture.
          Expanded(
            child: Center(
              child: ready
                  ? Stack(
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(AppRadius.sm), child: CameraPreview(camCtrl)),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedOpacity(
                              duration: Duration(milliseconds: _flash ? 0 : 220),
                              opacity: _flash ? 0.85 : 0,
                              child: const ColoredBox(color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),

          // Controls: video · shutter · gallery (bottom-right, like the system camera)
          ResponsiveCenter(
            maxWidth: Breakpoints.controls,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < Breakpoints.compact ? AppSpacing.xl : AppSpacing.xxl,
                AppSpacing.xl,
                MediaQuery.sizeOf(context).width < Breakpoints.compact ? AppSpacing.xl : AppSpacing.xxl,
                AppSpacing.xl,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _VideoButton(
                    recording: _isRecording,
                    onPressed: ready ? () => _toggleVideoRecording(controller) : null,
                  ),
                  _ShutterButton(enabled: ready && !_isRecording, onPressed: () => _capturePhoto(controller)),
                  _buildGalleryButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryButton() {
    final thumb = _lastThumbnailPath;
    return Tooltip(
      message: 'Upload from gallery',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: _isRecording ? null : _pickFromGallery,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isRecording ? 0.35 : 1,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                color: Colors.white.withValues(alpha: 0.08),
              ),
              clipBehavior: Clip.antiAlias,
              child: thumb != null
                  ? Image.file(
                      File(thumb),
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      errorBuilder: (_, _, _) => const Icon(Icons.photo_library_outlined, color: Colors.white),
                    )
                  : const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Review mode
  // ---------------------------------------------------------------------------

  Widget _buildReview(DetectionController controller) {
    return SafeArea(
      key: const ValueKey('review'),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  CameraChromeButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back to camera',
                    onPressed: _isProcessing ? null : () => setState(() => _capturedImage = null),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    _fromGallery ? 'Uploaded photo' : 'Review photo',
                    style: AppText.headline.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.file(File(_capturedImage!.path), fit: BoxFit.contain),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isProcessing ? 1 : 0,
                  child: IgnorePointer(ignoring: !_isProcessing, child: const _AnalyzingOverlay()),
                ),
              ],
            ),
          ),
          ResponsiveCenter(
            maxWidth: 560,
            child: Padding(
              padding: EdgeInsets.fromLTRB(pageGutter(context), AppSpacing.xl, pageGutter(context), AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                        minimumSize: const Size(0, 52),
                      ),
                      icon: Icon(_fromGallery ? Icons.photo_library_outlined : Icons.refresh_rounded, size: 20),
                      label: Text(_fromGallery ? 'Choose another' : 'Retake'),
                      onPressed: _isProcessing
                          ? null
                          : () {
                              if (_fromGallery) {
                                _pickFromGallery();
                              } else {
                                setState(() => _capturedImage = null);
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                      label: const Text('Analyze'),
                      onPressed: _isProcessing ? null : () => _processCapturedImage(controller),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Photo recovered after Android killed the app while the picker was open
    // (see HomeScreen._recoverLostPick): open straight into review.
    final args = ModalRoute.of(context)?.settings.arguments;
    if (_capturedImage == null && args is Map && args['recoveredImagePath'] is String) {
      final path = args['recoveredImagePath'] as String;
      _capturedImage = XFile(path);
      _fromGallery = true;
      _lastThumbnailPath = path;
    }
  }

  Future<void> _pickFromGallery() async {
    // Pause the preview while the system picker is in front: less memory held
    // in the background makes it less likely Android kills the app.
    final cam = context.read<DetectionController>().cameraService.controller;
    final paused = cam != null && cam.value.isInitialized && !cam.value.isPreviewPaused;
    try {
      if (paused) await cam.pausePreview();
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return; // user cancelled
      setState(() {
        _capturedImage = picked;
        _fromGallery = true;
        _lastThumbnailPath = picked.path;
      });
    } catch (e) {
      _showSnack('Could not open gallery: $e');
    } finally {
      if (paused && cam.value.isInitialized) {
        try {
          await cam.resumePreview();
        } catch (_) {}
      }
    }
  }

  Future<void> _capturePhoto(DetectionController controller) async {
    HapticFeedback.mediumImpact();
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _flash = false);
    });
    try {
      final file = await controller.cameraService.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedImage = file;
        _fromGallery = false;
        _lastThumbnailPath = file.path;
      });
    } catch (e) {
      _showSnack('Couldn\'t take the photo. Please try again.');
    }
  }

  Future<void> _toggleVideoRecording(DetectionController controller) async {
    HapticFeedback.mediumImpact();
    try {
      if (_isRecording) {
        final video = await controller.cameraService.stopVideoRecording();
        _recTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _recordedVideoPath = video.path;
        });
        _showSnack('Video saved');
      } else {
        await controller.cameraService.startVideoRecording();
        if (!mounted) return;
        setState(() {
          _isRecording = true;
          _recElapsed = Duration.zero;
        });
        _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recElapsed += const Duration(seconds: 1));
        });
      }
    } catch (e) {
      _recTimer?.cancel();
      if (mounted) setState(() => _isRecording = false);
      _showSnack('Video recording error: $e');
    }
  }

  Future<void> _processCapturedImage(DetectionController controller) async {
    if (_capturedImage == null) return;
    setState(() => _isProcessing = true);

    final path = _capturedImage!.path;
    final result = await controller.processImageFile(File(path));

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result != null) {
      HapticFeedback.lightImpact();
      Navigator.pushNamed(context, '/result', arguments: {'result': result, 'imagePath': path});
    } else {
      _showSnack('Analysis failed. Please try another photo.');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// -----------------------------------------------------------------------------

class _ShutterButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _ShutterButton({required this.enabled, required this.onPressed});

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take photo',
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _down = false);
                widget.onPressed();
              }
            : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: widget.enabled ? 1 : 0.35,
          child: Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3.5),
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 100),
              scale: _down ? 0.88 : 1,
              child: const DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoButton extends StatelessWidget {
  final bool recording;
  final VoidCallback? onPressed;
  const _VideoButton({required this.recording, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: recording ? 'Stop recording' : 'Record video',
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: recording
                    ? Container(
                        key: const ValueKey('stop'),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(4)),
                      )
                    : const Icon(Icons.videocam_outlined, key: ValueKey('cam'), color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyzingOverlay extends StatelessWidget {
  const _AnalyzingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.hairline),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: AppSpacing.lg),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analyzing shelf',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Detecting products and shelf rows',
                    style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
