import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/inference_frame_result.dart';
import '../../data/services/camera_service.dart';
import '../../platform/ai_platform_service.dart';

class DetectionController extends ChangeNotifier {
  final CameraService cameraService = CameraService();

  InferenceFrameResult? _lastResult;
  bool _isDetecting = false;
  bool _isLoading = false;
  String? _error;
  bool _cameraPermissionGranted = false;
  bool _modelLoaded = false;

  /// Throttle: track when the last frame was sent for inference.
  DateTime? _lastFrameTime;

  /// Bumped on every start/stop so results from frames captured before a
  /// pause are discarded instead of being drawn over the new camera view.
  int _liveSession = 0;
  static const _minFrameIntervalMs = 1000 ~/ AppConstants.targetFps;

  InferenceFrameResult? get lastResult => _lastResult;
  bool get isDetecting => _isDetecting;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get cameraPermissionGranted => _cameraPermissionGranted;
  bool get modelLoaded => _modelLoaded;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. AI Models initialize first (independent of camera or simulator status)
      await AiPlatformService.instance.initialize();
      _modelLoaded = AiPlatformService.instance.isLoaded;
    } catch (e) {
      _error = 'Failed to load AI models: $e';
    }

    try {
      // 2. Camera permission request
      final status = await Permission.camera.request();
      _cameraPermissionGranted = status.isGranted;
    } catch (_) {
      _cameraPermissionGranted = false;
    }

    // 3. Camera hardware initialization (if permission granted)
    if (_cameraPermissionGranted) {
      try {
        await cameraService.initialize();
      } catch (e) {
        // e.g. Simulator without camera hardware or hardware busy
        _cameraPermissionGranted = false;
        _error ??= 'Camera hardware unavailable: $e';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Live detection
  // ---------------------------------------------------------------------------

  void startLiveDetection() {
    if (_isDetecting || !cameraService.isInitialized) return;
    _isDetecting = true;
    _error = null;
    // Never show boxes from before the pause: they belong to an old camera position.
    _liveSession++;
    _lastResult = null;
    _lastFrameTime = null;
    AiPlatformService.instance.resetTiming();
    notifyListeners();

    cameraService.startImageStream(_onFrame);
  }

  void stopLiveDetection() {
    if (!_isDetecting) return;
    _isDetecting = false;
    _liveSession++;
    _lastResult = null;
    cameraService.stopImageStream();
    notifyListeners();
  }

  void _onFrame(CameraImage image) {
    // Throttle to the target FPS and drop frames while the worker is busy,
    // so results always reflect the most recent camera position.
    final now = DateTime.now();
    if (_lastFrameTime != null && now.difference(_lastFrameTime!).inMilliseconds < _minFrameIntervalMs) {
      return;
    }
    if (AiPlatformService.instance.isBusy) return;
    _lastFrameTime = now;
    final session = _liveSession;

    AiPlatformService.instance
        .processFrame(image, cameraService.sensorOrientation)
        .then((result) {
          if (result == null || !_isDetecting || session != _liveSession) return;
          _lastResult = result;
          _error = null;
          notifyListeners();
        })
        .catchError((Object e) {
          if (!_isDetecting || session != _liveSession) return;
          _error = 'Frame error: $e';
          notifyListeners();
        });
  }

  // ---------------------------------------------------------------------------
  // Single-image processing
  // ---------------------------------------------------------------------------

  Future<InferenceFrameResult?> processImageFile(File f) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await AiPlatformService.instance.processImageFile(f);
      _lastResult = result;
      return result;
    } catch (e) {
      _error = 'Image processing error: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    stopLiveDetection();
    cameraService.dispose();
    AiPlatformService.instance.dispose();
    super.dispose();
  }
}
