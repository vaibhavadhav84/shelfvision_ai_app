# ShelfVision AI — AI Inference & Computer Vision Guide

A complete guide explaining YOLO11, object detection, instance segmentation, tensor layouts, and on-device postprocessing in simple, intuitive terms.

---

## 1. What is YOLO11?

**YOLO** stands for *You Only Look Once*. Unlike traditional two-stage detectors (e.g., Faster R-CNN) that first propose regions and then classify each region, YOLO processes the entire image in a single forward pass through a convolutional/transformer neural network.

**YOLO11** is the latest state-of-the-art vision architecture from Ultralytics (late 2024), featuring:
- Enhanced feature extraction using **C3k2** blocks.
- Advanced spatial attention via **SPPF** (Spatial Pyramid Pooling - Fast).
- Extremely low parameter count in the `n` (nano) variants: ~2.6M parameters for detection and ~2.8M for segmentation.

---

## 2. Object Detection vs. Instance Segmentation

| Characteristic | Object Detection (Model A) | Instance Segmentation (Model B) |
|---|---|---|
| **Objective** | Locate items with bounding boxes | Delineate exact pixel boundaries |
| **Model** | `detect_product_empty_space.pt` | `segment_shelf_rows.pt` |
| **Classes** | `0: empty`, `1: product` | `0: row` |
| **Output Shape** | `[1, 6, 8400]` | `output0: [1, 37, 8400]`, `output1: [1, 32, 160, 160]` |
| **Visual Output** | Rectangles with label & confidence | Filled colored polygon outlines |

---

## 3. Image Preprocessing: Why and How

Neural networks do not understand raw JPEG files or Android camera memory planes directly. Three crucial steps are performed:

### Step 1: YUV420 to RGB Conversion
Android cameras stream images in `YUV_420_888` format (1 luminance channel Y, 2 chrominance channels U and V). We convert these channels to RGB using standard color transformation matrices:
- $R = Y + 1.370705 \times (V - 128)$
- $G = Y - 0.698001 \times (V - 128) - 0.337633 \times (U - 128)$
- $B = Y + 1.732446 \times (U - 128)$

### Step 2: Letterbox Resizing
If an image of $1280 \times 720$ is stretched directly to $640 \times 640$, the aspect ratio changes, warping bottles and boxes. 
Instead, we:
1. Scale the image proportionally so the largest dimension is 640.
2. Center the scaled image inside a $640 \times 640$ canvas.
3. Fill remaining borders with gray ($R=114, G=114, B=114$).
4. Keep track of `padX`, `padY`, and `scale` to reverse the coordinates later.

### Step 3: NCHW Normalization
PyTorch models expect tensor format `[Batch, Channels, Height, Width]` where pixel values are in the range $[0.0, 1.0]$:
```dart
result[idx] = pixel.r / 255.0;            // Red plane
result[size + idx] = pixel.g / 255.0;      // Green plane
result[size * 2 + idx] = pixel.b / 255.0;  // Blue plane
```

---

## 4. Decoding Model A: Detection Tensor `[1, 6, 8400]`

The output tensor has shape `[1, 6, 8400]`:
- **8400**: The number of anchor candidate locations across 3 feature map scales ($80\times80 + 40\times40 + 20\times20 = 6400 + 1600 + 400 = 8400$).
- **6**: The values predicted at each anchor:
  - Row 0: Center X ($cx$) in 640-pixel coordinates
  - Row 1: Center Y ($cy$) in 640-pixel coordinates
  - Row 2: Box Width ($w$)
  - Row 3: Box Height ($h$)
  - Row 4: Confidence score for Class 0 (`empty`)
  - Row 5: Confidence score for Class 1 (`product`)

### Conversion to Corner Coordinates:
$$x_1 = cx - \frac{w}{2}, \quad y_1 = cy - \frac{h}{2}$$
$$x_2 = cx + \frac{w}{2}, \quad y_2 = cy + \frac{h}{2}$$

---

## 5. Decoding Model B: Instance Segmentation

YOLO11-seg uses the **YOLACT** prototype mask approach to achieve fast instance segmentation:

1. **`output0` [1, 37, 8400]**:
   - Rows 0–3: Bounding box ($cx, cy, w, h$)
   - Row 4: Class score for `row`
   - Rows 5–36: **32 mask coefficients** ($C_1, \dots, C_{32}$)
2. **`output1` [1, 32, 160, 160]**:
   - **32 prototype mask feature maps** of size $160 \times 160$.

### Reconstructing the Row Mask:
For each surviving detection, the final mask $M(x, y)$ is the dot product of its 32 coefficients with the 32 prototype planes, followed by a sigmoid activation:
$$M(x, y) = \sigma \left( \sum_{k=1}^{32} C_k \times \text{Proto}_k(x, y) \right)$$
Pixel values $\ge 0.5$ belong to the segmented shelf row!

---

## 6. Non-Maximum Suppression (NMS)

Because neighboring anchors often detect the same physical item, the model outputs multiple overlapping candidate boxes.

**NMS Algorithm:**
1. Sort candidate boxes in descending order of confidence score.
2. Pick the box with the highest score and add it to `kept`.
3. Calculate **Intersection over Union (IoU)** between this box and all remaining boxes:
   $$\text{IoU} = \frac{\text{Area of Overlap}}{\text{Area of Union}}$$
4. Suppress (discard) any box with $\text{IoU} > 0.45$.
5. Repeat for all remaining boxes.

---

## 7. Inverse Coordinate Mapping

To draw the predictions back onto the user's phone screen:
1. **Subtract padding**: $x_{\text{unpad}} = x_{\text{model}} - \text{padX}$
2. **Divide by letterbox scale**: $x_{\text{orig}} = \frac{x_{\text{unpad}}}{\text{scale}}$
3. **Scale to Flutter Widget Display**: $x_{\text{disp}} = x_{\text{orig}} \times \left(\frac{\text{PreviewWidth}}{\text{OriginalWidth}}\right)$

