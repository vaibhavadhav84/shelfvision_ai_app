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
      // 1. Camera permission
      final status = await Permission.camera.request();
      _cameraPermissionGranted = status.isGranted;
      if (!_cameraPermissionGranted) {
        throw Exception('Camera permission denied');
      }

      // 2. Camera hardware
      await cameraService.initialize();

      // 3. AI models
      await AiPlatformService.instance.initialize();
      _modelLoaded = AiPlatformService.instance.isLoaded;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Live detection
  // ---------------------------------------------------------------------------

  void startLiveDetection() {
    if (_isDetecting || !cameraService.isInitialized) return;
    _isDetecting = true;
    _error = null;
    notifyListeners();

    cameraService.startImageStream(_onFrame);
  }

  void stopLiveDetection() {
    if (!_isDetecting) return;
    _isDetecting = false;
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

    AiPlatformService.instance
        .processFrame(image, cameraService.sensorOrientation)
        .then((result) {
          if (result == null || !_isDetecting) return;
          _lastResult = result;
          _error = null;
          notifyListeners();
        })
        .catchError((Object e) {
          if (!_isDetecting) return;
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
