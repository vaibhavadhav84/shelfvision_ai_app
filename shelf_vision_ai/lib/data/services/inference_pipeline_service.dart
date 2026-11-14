import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/image_utils.dart';
import '../models/detection_result.dart';
import '../models/inference_frame_result.dart';
import '../models/segmentation_result.dart';
import 'ai_detection_service.dart';
import 'model_preprocessing_service.dart';
import 'shelf_segmentation_service.dart';

/// Runs the full AI pipeline (preprocess → detect → segment → postprocess)
/// in a long-lived background isolate so the camera preview and UI never
/// block. Both ONNX sessions live inside that isolate.
class InferencePipelineService {
  Isolate? _isolate;
  SendPort? _workerPort;
  final ReceivePort _replies = ReceivePort();
  final Map<int, Completer<InferenceFrameResult>> _pending = {};
  int _nextId = 0;
  bool _initialized = false;
  bool _isProcessing = false;
  DateTime? _lastResultTime;

  bool get isInitialized => _initialized;
  bool get isProcessing => _isProcessing;

  Future<void> initialize() async {
    if (_initialized) return;
    final det = await rootBundle.load(AppConstants.modelDetect);
    final seg = await rootBundle.load(AppConstants.modelSegment);

    final ready = Completer<SendPort>();
    _replies.listen((msg) {
      if (msg is SendPort) {
        ready.complete(msg);
      } else if (msg is _WorkerReply) {
        final c = _pending.remove(msg.id);
        if (c == null) return;
        if (msg.error != null) {
          c.completeError(Exception(msg.error));
        } else {
          c.complete(msg.result!);
        }
      } else if (msg is String && !ready.isCompleted) {
        ready.completeError(Exception(msg));
      }
    });

    _isolate = await Isolate.spawn(
      _workerMain,
      _WorkerInit(
        _replies.sendPort,
        TransferableTypedData.fromList([det.buffer.asUint8List(det.offsetInBytes, det.lengthInBytes)]),
        TransferableTypedData.fromList([seg.buffer.asUint8List(seg.offsetInBytes, seg.lengthInBytes)]),
      ),
      debugName: 'ShelfVisionInference',
    );
    _workerPort = await ready.future;
    _initialized = true;
  }

  /// Live frame. Returns null (frame dropped) if the previous frame is still
  /// being processed — this keeps latency low instead of queueing frames.
  Future<InferenceFrameResult?> processFrame(YuvFrame frame, int sensorOrientation) async {
    if (_isProcessing || !_initialized) return null;
    _isProcessing = true;
    try {
      final r = await _send(_FrameJob(frame, sensorOrientation));
      final now = DateTime.now();
      final last = _lastResultTime;
      _lastResultTime = now;
      final ms = last == null ? 0 : now.difference(last).inMilliseconds;
      return r.copyWith(fps: ms > 0 ? 1000.0 / ms : 0.0);
    } finally {
      _isProcessing = false;
    }
  }

  Future<InferenceFrameResult> processImageFile(String path) {
    if (!_initialized) throw StateError('Models not loaded');
    return _send(_FileJob(path));
  }

  Future<InferenceFrameResult> _send(Object job) {
    final id = _nextId++;
    final c = Completer<InferenceFrameResult>();
    _pending[id] = c;
    _workerPort!.send(_WorkerRequest(id, job));
    return c.future;
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _replies.close();
    for (final c in _pending.values) {
      c.completeError(StateError('Pipeline disposed'));
    }
    _pending.clear();
    _initialized = false;
  }
}

// ----------------------------------------------------------------------------
// Worker isolate
// ----------------------------------------------------------------------------

class _WorkerInit {
  final SendPort replyPort;
  final TransferableTypedData detModel;
  final TransferableTypedData segModel;
  _WorkerInit(this.replyPort, this.detModel, this.segModel);
}

class _WorkerRequest {
  final int id;
  final Object job;
  _WorkerRequest(this.id, this.job);
}

class _FrameJob {
  final YuvFrame frame;
  final int rotation;
  _FrameJob(this.frame, this.rotation);
}

class _FileJob {
  final String path;
  _FileJob(this.path);
}

class _WorkerReply {
  final int id;
  final InferenceFrameResult? result;
  final String? error;
  _WorkerReply(this.id, {this.result, this.error});
}

void _workerMain(_WorkerInit init) {
  final detection = AiDetectionService();
  final segmentation = ShelfSegmentationService();
  final preprocessor = ModelPreprocessingService();
  try {
    OrtEnv.instance.init();
    detection.initialize(init.detModel.materialize().asUint8List());
    segmentation.initialize(init.segModel.materialize().asUint8List());
  } catch (e) {
    init.replyPort.send('Failed to load models: $e');
    return;
  }

  final port = ReceivePort();
  init.replyPort.send(port.sendPort);

  port.listen((msg) {
    if (msg is! _WorkerRequest) return;
    try {
      final sw = Stopwatch()..start();
      final job = msg.job;
      final LetterboxTensor lb = job is _FrameJob
          ? preprocessor.preprocessYuvFrame(job.frame, job.rotation)
          : preprocessor.preprocessImageFile((job as _FileJob).path);
      final DetectionResult det = detection.runInference(lb);
      final SegmentationResult seg = segmentation.runInference(lb);
      init.replyPort.send(_WorkerReply(
        msg.id,
        result: InferenceFrameResult(
          detectionResult: det,
          segmentationResult: seg,
          totalInferenceMs: sw.elapsedMicroseconds / 1000.0,
          fps: 0,
          timestamp: DateTime.now(),
          imageSize: Size(lb.origWidth.toDouble(), lb.origHeight.toDouble()),
        ),
      ));
    } catch (e) {
      init.replyPort.send(_WorkerReply(msg.id, error: e.toString()));
    }
  });
}
