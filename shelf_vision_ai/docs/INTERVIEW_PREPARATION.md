# ShelfVision AI — Technical Interview Preparation Guide

Use this guide to master and articulate the concepts, architecture, and code of **ShelfVision AI** during technical interviews.

---

## 1. Verbal Pitches

### 30-Second Elevator Pitch
> *"ShelfVision AI is an intelligent Android application built with Flutter and ONNX Runtime that uses computer vision to audit supermarket shelves in real time. Running directly on-device, it simultaneously executes two custom YOLO11 models: one that segments horizontal shelf rows, and another that detects individual products and flags empty shelf gaps. This gives store associates an instant live readout of stock levels, row structure, and restocking needs without relying on cloud connectivity."*

### 1-Minute Technical Summary
> *"From an engineering perspective, ShelfVision AI combines Flutter Material 3 with on-device AI acceleration via ONNX Runtime. We take the raw YUV420 camera stream from Android's camera hardware, convert and letterbox it to a 640x640 planar NCHW float32 tensor, and feed it into a sequential two-model pipeline. Model A is a YOLO11n detector identifying products and empty shelf gaps from a [1, 6, 8400] output tensor. Model B is a YOLO11n-seg instance segmenter that outputs [1, 37, 8400] boxes and coefficients alongside [1, 32, 160, 160] prototype masks to delineate exact shelf rows. By running these sequentially on the same preprocessed frame with a latest-frame-only drop policy, we maintain a smooth 60 FPS camera preview with 4–6 FPS on-device inference without memory leaks or UI jank."*

### 3-Minute Architecture Deep Dive
> *"When designing ShelfVision AI, our primary objective was running two neural networks on mobile hardware without compromising user experience. 
> 
> The architecture is organized in four clean layers:
> 1. **Core Layer**: Contains image preprocessing utilities (`ImageUtils`) and coordinate transformations (`CoordinateUtils`). Mobile cameras stream in YUV420, so we convert this to RGB, apply letterboxing to prevent aspect-ratio distortion, and normalize pixels to [0.0, 1.0] in NCHW format.
> 2. **Data Layer**: Contains our ONNX Runtime services. We chose ONNX Runtime over TFLite because YOLO11-seg uses dual output tensors (coefficients and prototype masks) that standard mobile runtimes struggle to parse without custom C++ ops. `InferencePipelineService` manages both models sequentially. Reusing the preprocessed buffer cuts memory allocations in half.
> 3. **Platform Layer**: Exposes `AiPlatformService` as a clean facade, offering reactive streams to decouple UI from AI lifecycle.
> 4. **Presentation Layer**: Built with Flutter Material 3 and Provider. Instead of widget-heavy trees, we use GPU-accelerated `CustomPainter` canvases to draw bounding boxes and transparent segmentation polygons.
> 
> To prevent frame queues from lagging behind real life, our controller enforces a latest-frame-only policy: if inference is in progress, new camera frames are discarded until the model finishes, guaranteeing that the visual overlays match what the camera is seeing in real time."*

---

## 2. Common Interview Questions & Expert Answers

### Q1: Why did you choose ONNX Runtime instead of TensorFlow Lite (TFLite/LiteRT)?
**Answer**:
> *"While TFLite is widely used, YOLO11 instance segmentation models (`yolo11n-seg`) output two separate tensors: `output0` of shape `[1, 37, 8400]` (containing coordinates, class confidence, and 32 mask coefficients) and `output1` of shape `[1, 32, 160, 160]` (containing 32 prototype masks). In TFLite, custom ops and dual output tensor mapping often fail or require custom C++ kernels. ONNX Runtime provides 100% operator compatibility with Ultralytics exports out of the box, ensuring zero deviation between Python training and mobile execution."*

### Q2: What is the significance of letterbox resizing? Why not just stretch the image to 640x640?
**Answer**:
> *"Stretching an image distorts its aspect ratio. A tall, thin bottle would become squashed or wide, changing its visual geometry and lowering the model's confidence. Letterboxing scales the image proportionally so the largest dimension fits 640, and pads the remaining margins with a neutral gray (114, 114, 114). We store the padding offsets (`padX`, `padY`) and the scale factor so we can map predicted coordinates back to the original screen dimensions with zero distortion."*

### Q3: How do you extract segmentation masks from the YOLO11-seg model?
**Answer**:
> *"YOLO11-seg uses the YOLACT prototype approach. The model produces 32 prototype mask feature maps of size 160x160 (`output1`), and predicts 32 scalar coefficients for each detected box (`output0`). For each detection, we compute the linear combination (dot product) of its 32 coefficients with the 32 prototype feature maps, apply a sigmoid activation, and threshold values at 0.5. This produces a binary mask that delineates the physical boundary of the shelf row."*

### Q4: How do you prevent UI thread blocking during live camera inference?
**Answer**:
> *"The entire AI pipeline runs in a dedicated, long-lived background isolate (`InferencePipelineService`). Both ONNX sessions are created inside that isolate (the onnxruntime plugin is pure FFI, so it works off the main isolate). The UI isolate only copies the YUV planes and sends them over a SendPort; YUV→RGB, rotation, letterboxing, both model runs, NMS and mask decoding all happen in the worker, which returns ready-to-draw results in image-pixel coordinates. The controller caps frames at 10 FPS and drops any frame while the worker is busy (latest-frame-only), so results always reflect where the camera is pointing now. Overlays are drawn with `CustomPainter` using the same BoxFit.cover mapping as the preview, so boxes stay aligned."*

### Q5: How do you prevent native memory leaks when dealing with camera frames and ONNX tensors?
**Answer**:
> *"Both camera images and ONNX tensors allocate off-heap native memory. In `AiDetectionService` and `ShelfSegmentationService`, every `OrtValueTensor` and `OrtRunOptions` allocated during inference is explicitly released via `.release()` inside a finally block. When navigating away, `dispose()` is called on the camera controller and ONNX sessions."*

---

## 3. Quick Reference: Where to Find Key Code

| Requirement / Component | File | Key Method / Class |
|---|---|---|
| Camera Initialization | `lib/data/services/camera_service.dart` | `_initCamera()`, `ResolutionPreset.medium` |
| YUV → rotate → letterbox → NCHW (one pass, stride-aware) | `lib/core/utils/image_utils.dart` | `yuvToLetterboxTensor()` |
| Still image letterbox (EXIF-corrected, anti-aliased) | `lib/data/services/model_preprocessing_service.dart` | `preprocessImageFile()` |
| Background inference isolate | `lib/data/services/inference_pipeline_service.dart` | `_workerMain()` |
| Per-row stock / empty % (reference-repo logic) | `lib/data/models/shelf_analytics.dart` | `ShelfAnalytics.fromResult()` |
| Model A Loading & Run | `lib/data/services/ai_detection_service.dart` | `initialize()`, `runInference()` |
| Model B Loading & Run | `lib/data/services/shelf_segmentation_service.dart` | `initialize()`, `runInference()` |
| Bounding Box Decoding & NMS | `lib/data/services/model_postprocessing_service.dart`| `parseDetectionOutput()`, `_nms()` |
| Prototype Mask Decoding (cropped to box, ordered outline) | `lib/data/services/model_postprocessing_service.dart`| `parseSegmentationOutput()`, `_maskOutline()` |
| Inverse Coordinate Transform | `lib/core/utils/coordinate_utils.dart` | `modelBoxToDisplayRect()`, `ImageToViewMapper` |
| Overlay Painting | `lib/presentation/widgets/` | `ProductDetectionOverlay`, `ShelfSegmentationOverlay` |
| Frame Throttling & Queue | `lib/presentation/controllers/detection_controller.dart`| `_onFrame()`, `_minFrameIntervalMs` |

