import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:onnxruntime/onnxruntime.dart';
// The package only exposes outputs via `OrtValueTensor.value`, which reads
// every element through a separate FFI call into boxed nested Lists
// (~1.1M values per frame for our two models, ~seconds on a phone).
// We read the native float buffer directly through the ORT C API instead.
// ignore: implementation_imports
import 'package:onnxruntime/src/bindings/onnxruntime_bindings_generated.dart' as bg;

class OrtTensorReader {
  OrtTensorReader._();

  /// Copies a float32 output tensor into a contiguous [Float32List] with a
  /// single memcpy. Must be called before the OrtValue is released.
  static Float32List readFloat32(OrtValue value) {
    final api = OrtEnv.instance.ortApiPtr.ref;
    final ptr = value.ptr;

    // Element count from the tensor's own shape info (never trust a hardcoded size).
    final infoPtrPtr = calloc<ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>>();
    final countPtr = calloc<ffi.Size>();
    final typePtr = calloc<ffi.Int32>();
    final dataPtrPtr = calloc<ffi.Pointer<ffi.Void>>();
    try {
      OrtStatus.checkOrtStatus(api.GetTensorTypeAndShape.asFunction<
          bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtValue>,
              ffi.Pointer<ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>>)>()(ptr, infoPtrPtr));
      final info = infoPtrPtr.value;
      try {
        OrtStatus.checkOrtStatus(api.GetTensorElementType.asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>, ffi.Pointer<ffi.Int32>)>()(info, typePtr));
        OrtStatus.checkOrtStatus(api.GetTensorShapeElementCount.asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>, ffi.Pointer<ffi.Size>)>()(info, countPtr));
      } finally {
        api.ReleaseTensorTypeAndShapeInfo
            .asFunction<void Function(ffi.Pointer<bg.OrtTensorTypeAndShapeInfo>)>()(info);
      }
      if (typePtr.value != ONNXTensorElementDataType.float.value) {
        throw StateError('Expected float32 output tensor, got element type ${typePtr.value}');
      }

      OrtStatus.checkOrtStatus(api.GetTensorMutableData.asFunction<
          bg.OrtStatusPtr Function(
              ffi.Pointer<bg.OrtValue>, ffi.Pointer<ffi.Pointer<ffi.Void>>)>()(ptr, dataPtrPtr));
      final int count = countPtr.value;
      return Float32List.fromList(dataPtrPtr.value.cast<ffi.Float>().asTypedList(count));
    } finally {
      calloc.free(infoPtrPtr);
      calloc.free(countPtr);
      calloc.free(typePtr);
      calloc.free(dataPtrPtr);
    }
  }
}
