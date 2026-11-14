"""
ShelfVision AI — Model Validation Script
Validates detect_product_empty_space.pt and segment_shelf_rows.pt
"""

import os
import sys
import json
import cv2
import numpy as np
from pathlib import Path
from ultralytics import YOLO

# ── Paths ────────────────────────────────────────────────────────────────────
BASE_DIR   = Path(__file__).resolve().parents[2]          # shelf_vision_ai/
MODELS_DIR = BASE_DIR / "assets" / "models"
IMAGES_DIR = BASE_DIR / "assets" / "images"
RESULTS_DIR = BASE_DIR / "docs" / "model_test_results"

DETECT_PT  = MODELS_DIR / "detect_product_empty_space.pt"
SEGMENT_PT = MODELS_DIR / "segment_shelf_rows.pt"

TEST_IMAGES = [IMAGES_DIR / "1.jpeg", IMAGES_DIR / "2.jpg"]

RESULTS_DIR.mkdir(parents=True, exist_ok=True)

results_summary = {}

# ── Helper ────────────────────────────────────────────────────────────────────
def print_section(title):
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70)

def model_meta(model, name):
    print_section(f"Metadata — {name}")
    info = model.info(detailed=False, verbose=False)
    # model.model attributes
    m = model.model
    task = getattr(model, 'task', 'unknown')
    nc   = getattr(m, 'nc', getattr(model, 'nc', 'unknown'))
    names = getattr(m, 'names', getattr(model, 'names', {}))
    imgsz = getattr(model, 'overrides', {}).get('imgsz', 'unknown')
    model_type = type(m).__name__

    print(f"  Task       : {task}")
    print(f"  nc         : {nc}")
    print(f"  names      : {names}")
    print(f"  imgsz      : {imgsz}")
    print(f"  model_type : {model_type}")
    return {"task": task, "nc": nc, "names": str(names), "imgsz": imgsz, "model_type": model_type}

# ── Load models ───────────────────────────────────────────────────────────────
print_section("Loading Models")
print(f"  detect_product_empty_space.pt → {DETECT_PT}")
detect_model = YOLO(str(DETECT_PT))
print(f"  segment_shelf_rows.pt         → {SEGMENT_PT}")
segment_model = YOLO(str(SEGMENT_PT))
print("  Both models loaded successfully.")

# ── Metadata ──────────────────────────────────────────────────────────────────
detect_meta  = model_meta(detect_model,  "detect_product_empty_space")
segment_meta = model_meta(segment_model, "segment_shelf_rows")
results_summary["detect_meta"]  = detect_meta
results_summary["segment_meta"] = segment_meta

# ── Inference ─────────────────────────────────────────────────────────────────
detect_results_data  = {}
segment_results_data = {}

for img_path in TEST_IMAGES:
    img_key = img_path.name  # "1.jpeg" / "2.jpg"
    idx     = img_path.stem  # "1" / "2"

    print_section(f"Detection Inference — {img_key}")
    det_res = detect_model(str(img_path), verbose=False)
    dr = det_res[0]

    boxes_data = []
    if dr.boxes is not None and len(dr.boxes):
        for box in dr.boxes:
            cls_id = int(box.cls.item())
            conf   = float(box.conf.item())
            xyxy   = box.xyxy[0].tolist()
            class_name = detect_model.names.get(cls_id, str(cls_id))
            boxes_data.append({"cls_id": cls_id, "class": class_name, "conf": round(conf, 4), "xyxy": [round(v,1) for v in xyxy]})
            print(f"  Box: cls={cls_id}({class_name})  conf={conf:.4f}  xyxy={[round(v,1) for v in xyxy]}")
    else:
        print("  No detections.")

    # Save annotated image
    annotated = dr.plot()
    out_path = RESULTS_DIR / f"detect_{idx}.jpg"
    cv2.imwrite(str(out_path), annotated)
    print(f"  Saved annotated → {out_path}")

    detect_results_data[img_key] = {"boxes": boxes_data, "num_detections": len(boxes_data)}

    print_section(f"Segmentation Inference — {img_key}")
    seg_res = segment_model(str(img_path), verbose=False)
    sr = seg_res[0]

    masks_data = []
    if sr.masks is not None and sr.masks.data is not None:
        num_masks = sr.masks.data.shape[0]
        print(f"  Masks shape : {sr.masks.data.shape}")
        for i in range(num_masks):
            cls_id = int(sr.boxes.cls[i].item()) if sr.boxes is not None else -1
            conf   = float(sr.boxes.conf[i].item()) if sr.boxes is not None else -1
            class_name = segment_model.names.get(cls_id, str(cls_id))
            mask_shape = tuple(sr.masks.data[i].shape)
            xyxy = sr.boxes.xyxy[i].tolist() if sr.boxes is not None else []
            masks_data.append({
                "idx": i, "cls_id": cls_id, "class": class_name,
                "conf": round(conf, 4), "mask_shape": mask_shape,
                "xyxy": [round(v,1) for v in xyxy]
            })
            print(f"  Mask[{i}]: cls={cls_id}({class_name})  conf={conf:.4f}  mask_shape={mask_shape}  xyxy={[round(v,1) for v in xyxy]}")
    else:
        num_masks = 0
        print("  No segmentation masks returned.")

    # Save annotated image
    annotated_seg = sr.plot()
    out_seg_path = RESULTS_DIR / f"segment_{idx}.jpg"
    cv2.imwrite(str(out_seg_path), annotated_seg)
    print(f"  Saved annotated → {out_seg_path}")

    segment_results_data[img_key] = {"masks": masks_data, "num_masks": num_masks}

results_summary["detect_results"]  = detect_results_data
results_summary["segment_results"] = segment_results_data

# ── ONNX Export ───────────────────────────────────────────────────────────────
print_section("ONNX Export — detect_product_empty_space.pt")
detect_onnx_path = detect_model.export(
    format="onnx",
    imgsz=640,
    half=False,
    simplify=True,
)
# Move to assets/models if exported elsewhere
detect_onnx_src = Path(detect_onnx_path)
detect_onnx_dst = MODELS_DIR / "detect_product_empty_space.onnx"
if detect_onnx_src.resolve() != detect_onnx_dst.resolve():
    import shutil
    shutil.copy2(str(detect_onnx_src), str(detect_onnx_dst))
    print(f"  Copied {detect_onnx_src} → {detect_onnx_dst}")
else:
    print(f"  Exported to {detect_onnx_dst}")
detect_onnx_size = detect_onnx_dst.stat().st_size
print(f"  File size: {detect_onnx_size:,} bytes ({detect_onnx_size/1024/1024:.2f} MB)")

print_section("ONNX Export — segment_shelf_rows.pt")
segment_onnx_path = segment_model.export(
    format="onnx",
    imgsz=640,
    half=False,
    simplify=True,
)
segment_onnx_src = Path(segment_onnx_path)
segment_onnx_dst = MODELS_DIR / "segment_shelf_rows.onnx"
if segment_onnx_src.resolve() != segment_onnx_dst.resolve():
    import shutil
    shutil.copy2(str(segment_onnx_src), str(segment_onnx_dst))
    print(f"  Copied {segment_onnx_src} → {segment_onnx_dst}")
else:
    print(f"  Exported to {segment_onnx_dst}")
segment_onnx_size = segment_onnx_dst.stat().st_size
print(f"  File size: {segment_onnx_size:,} bytes ({segment_onnx_size/1024/1024:.2f} MB)")

results_summary["onnx_exports"] = {
    "detect": {"path": str(detect_onnx_dst), "size_bytes": detect_onnx_size},
    "segment": {"path": str(segment_onnx_dst), "size_bytes": segment_onnx_size},
}

# ── ONNX Tensor Shape Inspection ─────────────────────────────────────────────
print_section("ONNX Output Tensor Shapes")
try:
    import onnx
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "onnx", "-q"])
    import onnx

def inspect_onnx(onnx_path, label):
    model_onnx = onnx.load(str(onnx_path))
    print(f"\n  [{label}]")
    print("  INPUTS:")
    for inp in model_onnx.graph.input:
        shape = [d.dim_value if d.dim_value else d.dim_param for d in inp.type.tensor_type.shape.dim]
        print(f"    {inp.name}: {shape}")
    print("  OUTPUTS:")
    out_shapes = []
    for out in model_onnx.graph.output:
        shape = [d.dim_value if d.dim_value else d.dim_param for d in out.type.tensor_type.shape.dim]
        print(f"    {out.name}: {shape}")
        out_shapes.append({"name": out.name, "shape": shape})
    return out_shapes

detect_out_shapes  = inspect_onnx(detect_onnx_dst,  "detect_product_empty_space")
segment_out_shapes = inspect_onnx(segment_onnx_dst, "segment_shelf_rows")

results_summary["onnx_output_shapes"] = {
    "detect":  detect_out_shapes,
    "segment": segment_out_shapes,
}

# ── Save JSON summary ─────────────────────────────────────────────────────────
json_out = RESULTS_DIR / "validation_summary.json"
with open(json_out, "w") as f:
    json.dump(results_summary, f, indent=2, default=str)
print_section(f"Summary saved → {json_out}")
print(json.dumps(results_summary, indent=2, default=str))
