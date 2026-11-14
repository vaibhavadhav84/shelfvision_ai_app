# ShelfVision AI — Technical Architecture Guide

This guide is designed for developers and interviewers to understand the complete engineering design, data flow, and runtime choices behind **ShelfVision AI**.

---

## 1. High-Level Architecture Overview

ShelfVision AI is structured into four distinct layers following Clean Architecture principles:

```
lib/
├── main.dart                          <-- Entry point, orientation lock
├── app/
│   └── app.dart                       <-- Material 3 configuration, route mapping, theme
├── core/
│   ├── constants/
│   │   └── app_constants.dart         <-- Thresholds, model paths, color styling
│   └── utils/
│       ├── image_utils.dart           <-- YUV420 to RGB conversion, letterboxing, NCHW tensor
│       └── coordinate_utils.dart      <-- Inverse transformation & IoU bounding box math
├── data/
│   ├── models/
│   │   ├── detection_result.dart      <-- Product & Empty space boxes
│   │   ├── segmentation_result.dart   <-- Shelf row polygons & contours
│   │   └── inference_frame_result.dart<-- Combined multi-model metrics
│   └── services/
│       ├── camera_service.dart        <-- CameraX / AVFoundation camera lifecycle
│       ├── model_preprocessing_service.dart <-- Resizing & Float32 normalization
│       ├── model_postprocessing_service.dart<-- NMS, anchor parsing & prototype mask decoding
│       ├── ai_detection_service.dart  <-- Model A ONNX execution
│       ├── shelf_segmentation_service.dart <-- Model B ONNX execution
│       └── inference_pipeline_service.dart <-- Sequential multi-model coordinator
├── platform/
│   └── ai_platform_service.dart       <-- Singleton facade and reactive result stream
└── presentation/
    ├── controllers/
    │   └── detection_controller.dart  <-- State management (Provider), throttling, permissions
    ├── screens/
    │   ├── home_screen.dart           <-- Model readiness & entry options
    │   ├── live_detection_screen.dart <-- Real-time camera preview & dynamic overlays
    │   ├── capture_screen.dart        <-- High-res capture, video recording & manual analysis
    │   └── result_screen.dart         <-- Annotated photo inspector & confidence stats
    └── widgets/
        ├── camera_preview_widget.dart <-- Aspect ratio handling
        ├── product_detection_overlay.dart <-- CustomPainter bounding boxes
        ├── shelf_segmentation_overlay.dart<-- CustomPainter polygon masks
        ├── detection_summary_card.dart<-- Real-time KPI dashboard
        └── camera_controls.dart       <-- Capture & recording actions
```

---

## 2. Real-Time End-to-End Data Pipeline

The live detection pipeline executes on every sampled camera frame without blocking the UI thread:

```
Android Camera Hardware
         │ (YUV_420_888 frame)
         ▼
[CameraService]
         │ (startImageStream callback)
         ▼
[DetectionController] (10 FPS cap, latest-frame-only drop strategy)
         │ (YUV planes copied → SendPort)
         ▼
[InferencePipelineService — background worker isolate]
         │
         ├─► [ModelPreprocessingService]
         │       • Convert YUV420 to RGB (ImageUtils)
         │       • Rotate to portrait orientation
         │       • Letterbox resize (640x640, aspect-ratio preserved, gray 114 pad)
         │       • Normalize to [0.0, 1.0] in NCHW Float32List format
         │
         ├─► [AiDetectionService] (Model A — detect_product_empty_space.onnx)
         │       • Input tensor `images`: [1, 3, 640, 640]
         │       • Output tensor `output0`: [1, 6, 8400]
         │       • Extract cx, cy, w, h + class 0 (empty) + class 1 (product)
         │       • Apply confidence filter (threshold >= 0.25)
         │       • Apply Non-Maximum Suppression (IoU >= 0.45)
         │
         ├─► [ShelfSegmentationService] (Model B — segment_shelf_rows.onnx)
         │       • Input tensor `images`: [1, 3, 640, 640] (shared preprocessed buffer)
         │       • Output tensor `output0`: [1, 37, 8400] (boxes + row score + 32 mask coeffs)
         │       • Output tensor `output1`: [1, 32, 160, 160] (mask prototypes)
         │       • Dot product coefficients with prototypes -> 160x160 mask
         │       • Apply sigmoid & threshold at 0.5 -> extract polygon contour
         │
         └─► [Result Combination & Inverse Coordinate Transform]
                 • Remove padding & scaling back to camera/display coordinates
                 • Package into `InferenceFrameResult`
         │
         ▼
[Flutter UI Rendering Layer]
         • ShelfSegmentationOverlay (semi-transparent blue polygons)
         • ProductDetectionOverlay (green product boxes, red empty boxes)
         • DetectionSummaryCard (live counts, FPS, latency breakdown)
```

---

## 3. Key Technical Decisions & Justifications

### 3.1 Why ONNX Runtime for Android?
- **Universal YOLO11 Support**: YOLO11 introduces specialized architecture features (C3k2 blocks and instance segmentation heads). While LiteRT/TFLite struggles with custom ops or dual-tensor segmentation heads (`output0` + `output1` prototype masks), ONNX Runtime natively supports the exact operators exported by Ultralytics.
- **Cross-Platform Parity**: The same ONNX models run seamlessly across Android, iOS, and desktop test environments with zero quantization drift.

### 3.2 Why Sequential Inference Over Parallel Inference?
- On mobile devices, executing two heavy neural networks concurrently can saturate memory bandwidth and GPU compute units, leading to thermal throttling and dropped camera frames.
- By preprocessing the camera frame **once** and passing the resulting `Float32List` sequentially through Model A then Model B, we reduce memory allocations and achieve a steady, predictable 4–6 FPS on mid-range Android devices.

### 3.3 Latest-Frame-Only Drop Policy
- When the camera produces frames at 30 FPS but inference takes ~150–200 ms, buffering frames would create a growing lag where the screen shows detections for objects that moved seconds ago.
- The controller uses an `_isProcessing` guard: if inference is already executing, newly incoming camera frames are immediately dropped. The user always sees the most recent frame processed.

### 3.4 Hardware-Accelerated CustomPainter Overlays
- Instead of creating hundreds of Flutter `Widget` elements inside a `Stack`, detections and masks are drawn using `CustomPainter` onto a canvas.
- This results in 60 FPS UI rendering, minimal garbage collection pressure, and sub-millisecond redraw times.

