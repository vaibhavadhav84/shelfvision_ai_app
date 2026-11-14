# ShelfVision AI — Flutter Source Code Walkthrough

This document provides a line-by-line and file-by-file walkthrough of the ShelfVision AI codebase, highlighting the role, key methods, and interview talking points for each file.

---

## 1. Entry Point & Configuration

### `lib/main.dart`
- **Role**: Application entrypoint.
- **Key Code**:
  - `WidgetsFlutterBinding.ensureInitialized()`: Ensures the binary platform channels are ready before loading assets or camera drivers.
  - `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`: Locks device orientation to portrait so camera frame matrix calculations remain deterministic.
  - `runApp(const ShelfVisionApp())`: Mounts the top-level widget.

### `lib/app/app.dart`
- **Role**: App root, Material 3 theme configuration, and top-level state provider.
- **Key Code**:
  - `ChangeNotifierProvider(create: (_) => DetectionController()..initialize())`: Injects `DetectionController` above the entire navigation stack so both `HomeScreen` and `LiveDetectionScreen` share the same camera and model instance without reinitialization.
  - `routes`: Registers named routes (`/`, `/live`, `/capture`, `/result`).

### `lib/core/constants/app_constants.dart`
- **Role**: Centralized source of truth for all parameters.
- **Key Constants**:
  - `modelDetect` & `modelSegment`: Asset paths for ONNX weights.
  - `inputSize = 640`: Spatial input dimension expected by YOLO11.
  - `confidenceThreshold = 0.25`: Cutoff to filter out noise.
  - `iouThreshold = 0.45`: Standard NMS overlap cutoff.
  - `classEmpty = 0`, `classProduct = 1`, `classRow = 0`: Verified class IDs from Ultralytics metadata.

---

## 2. Mathematical Utilities

### `lib/core/utils/image_utils.dart`
- **Role**: Image processing operations required before model inference.
- **Key Methods**:
  - `yuv420ToImage(CameraImage)`: Extracts Y, U, and V planes, performs byte stride arithmetic, and constructs an RGB `img.Image`.
  - `letterboxResize(img.Image, int targetSize)`: Computes isotropic scaling factor, resizes the image, and composites it onto a $640 \times 640$ gray canvas ($114, 114, 114$). Returns `padX`, `padY`, and `scale`.
  - `imageToFloat32List(img.Image)`: Reorganizes pixel values into planar **NCHW** format ($[1, 3, 640, 640]$) and normalizes from $[0, 255]$ to $[0.0, 1.0]$.
  - `rotateImage(img.Image, int degrees)`: Rotates camera frames to match device orientation.

### `lib/core/utils/coordinate_utils.dart`
- **Role**: Coordinate geometry and bounding box transformations.
- **Key Methods**:
  - `modelBoxToDisplayRect(...)`: Inverts letterbox scaling and padding, mapping candidate boxes directly to screen canvas coordinates.
  - `iou(Rect a, Rect b)`: Computes Intersection over Union for NMS deduplication.

---

## 3. Data Models

### `lib/data/models/detection_result.dart`
- Encapsulates detected objects:
  - `DetectionBox`: Stores `rect`, `classId` ($0$ or $1$), `label` (`empty` or `product`), and `confidence`.
  - `DetectionResult`: Segregates detections into `products` and `emptySpaces`, plus `inferenceTimeMs`.

### `lib/data/models/segmentation_result.dart`
- Encapsulates segmented shelf structures:
  - `SegmentedRow`: Contains `boundingBox`, `maskContour` (polygon points), and `confidence`.
  - `SegmentationResult`: Contains a list of `SegmentedRow` objects and execution time.

### `lib/data/models/inference_frame_result.dart`
- Combines `DetectionResult` and `SegmentationResult` along with aggregate `totalInferenceMs`, `fps`, and timestamp.

---

## 4. AI & Inference Services

### `lib/data/services/ai_detection_service.dart`
- **Role**: Manages ONNX Runtime session for Model A (`detect_product_empty_space.onnx`).
- **Key Methods**:
  - `initialize(bytes)`: Creates the `OrtSession` from model bytes (loaded from the asset bundle on the main isolate and transferred to the worker isolate).
  - `runInference(lb)`: Converts the letterboxed `Float32List` into an `OrtValueTensor`, runs `_session.run(...)` synchronously inside the worker isolate, and passes the flattened output to `ModelPostprocessingService`.

### `lib/data/services/shelf_segmentation_service.dart`
- **Role**: Manages ONNX Runtime session for Model B (`segment_shelf_rows.onnx`).
- **Key Methods**:
  - `runInference(...)`: Extracts both `output0` ($[1, 37, 8400]$) and `output1` ($[1, 32, 160, 160]$) and parses instance segmentation contours.

### `lib/data/services/model_postprocessing_service.dart`
- **Role**: Core mathematical postprocessor.
- **Key Methods**:
  - `parseDetectionOutput(...)`: Decodes $[1, 6, 8400]$ tensor into bounding boxes and executes NMS per class.
  - `parseSegmentationOutput(...)`: Decodes bounding boxes and calculates dot products between 32 coefficients and prototype masks (only inside each row's box, like Ultralytics `crop_mask`), then traces an ordered outline polygon per row. All coordinates are returned in original image pixels.
  - `_nms(...)`: Generic, greedy IoU-based Non-Maximum Suppression.

### `lib/data/services/inference_pipeline_service.dart`
- **Role**: Owns a long-lived background isolate that runs the whole pipeline (preprocess → Model A → Model B → postprocess).
- Ensures Model A and Model B run sequentially on the **same preprocessed frame**, tracks overall FPS, and enforces the latest-frame-only drop policy via `_isProcessing`. The UI isolate never blocks on AI work.

### `lib/platform/ai_platform_service.dart`
- **Role**: Singleton facade over the inference pipeline (frame + still-image entry points).

---

## 5. Presentation Layer & State Management

### `lib/presentation/controllers/detection_controller.dart`
- Extends `ChangeNotifier`.
- Manages permission requests, camera lifecycle, frame throttling (10 FPS cap + drop-while-busy), live inference toggles, and photo/video execution.

### `lib/presentation/screens/home_screen.dart`
- Modern Material 3 dashboard showing live model status, camera permission checks, and entry points for live detection and photo capture.

### `lib/presentation/screens/live_detection_screen.dart`
- Full-screen real-time camera view with layered `CustomPaint` overlays:
  - Blue transparent polygon masks for shelf rows.
  - Green boxes for individual products.
  - Red boxes for empty shelf space alerts.
  - Live HUD card reporting FPS, detection time, segmentation time, and item counts.

### `lib/presentation/screens/capture_screen.dart`
- Allows taking high-resolution still photos or recording inspection videos. Provides retake and on-demand AI processing.

### `lib/presentation/screens/result_screen.dart`
- Dedicated detailed report screen for inspected photos, providing full breakdowns of all detected items, empty spaces, and confidence ratings.

