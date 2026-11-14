import 'dart:async';
import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initialized = false;
  StreamController<CameraImage>? _frameController;

  CameraController? get controller => _controller;
  bool get isInitialized => _initialized;
  Stream<CameraImage>? get frameStream => _frameController?.stream;

  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) throw Exception('No cameras found');
    _active = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
    await _initCamera(_active!);
  }

  CameraDescription? _active;

  Future<void> _initCamera(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.medium, // 720p - good balance for inference
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    _initialized = true;
  }

  Future<void> startImageStream(Function(CameraImage) onFrame) async {
    final c = _controller;
    if (c == null || c.value.isStreamingImages) return;
    await c.startImageStream(onFrame);
  }

  Future<void> stopImageStream() async {
    final c = _controller;
    if (c == null || !c.value.isStreamingImages) return;
    await c.stopImageStream();
  }

  Future<XFile> takePicture() async {
    if (!_initialized) throw Exception('Camera not initialized');
    return await _controller!.takePicture();
  }

  Future<void> startVideoRecording() async {
    if (!_initialized) throw Exception('Camera not initialized');
    await _controller!.startVideoRecording();
  }

  Future<XFile> stopVideoRecording() async {
    if (!_initialized) throw Exception('Camera not initialized');
    return await _controller!.stopVideoRecording();
  }

  int get sensorOrientation => _active?.sensorOrientation ?? 90;

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }
}
