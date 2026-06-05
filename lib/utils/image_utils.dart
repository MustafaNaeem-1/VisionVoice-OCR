import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';


/// Utility class that converts a [CameraImage] (YUV420 / BGRA8888) into
/// an [InputImage] that ML Kit can process.  Handles rotation mapping
/// on Android (sensor orientation + device rotation).
class ImageUtils {
  /// Maps CameraDescription's sensorOrientation + device rotation to the
  /// InputImageRotation enum used by ML Kit.
  static InputImageRotation rotationFromCamera({
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    // Sensor orientation is always 0, 90, 180, or 270
    int sensorOrientation = camera.sensorOrientation;

    // On iOS the sensor is always aligned with the display
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }

    // On Android we need to compensate for device rotation
    int deviceOrientationDegrees = 0;
    switch (deviceOrientation) {
      case DeviceOrientation.portraitUp:
        deviceOrientationDegrees = 0;
        break;
      case DeviceOrientation.landscapeLeft:
        deviceOrientationDegrees = 90;
        break;
      case DeviceOrientation.portraitDown:
        deviceOrientationDegrees = 180;
        break;
      case DeviceOrientation.landscapeRight:
        deviceOrientationDegrees = 270;
        break;
    }

    // Front cameras are mirrored
    if (camera.lensDirection == CameraLensDirection.front) {
      sensorOrientation = (360 - sensorOrientation) % 360;
      deviceOrientationDegrees = (360 - deviceOrientationDegrees) % 360;
    }

    int rotationCompensation =
        (sensorOrientation - deviceOrientationDegrees + 360) % 360;

    return InputImageRotationValue.fromRawValue(rotationCompensation) ??
        InputImageRotation.rotation0deg;
  }

  /// Converts a live [CameraImage] into an [InputImage] for ML Kit.
  /// Returns null if the image format is not supported.
  static InputImage? fromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    // --- Determine image format ---
    final InputImageFormat? format = _inputImageFormat(image.format.raw);
    if (format == null) return null;

    // --- Build rotation ---
    final InputImageRotation rotation = rotationFromCamera(
      camera: camera,
      deviceOrientation: deviceOrientation,
    );

    // --- Build InputImage bytes ---
    // On Android the image arrives as YUV420; on iOS as BGRA8888.
    // For Android we use the first plane (Y-plane) bytes wrapped in WriteBuffer.
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final Uint8List bytes = allBytes.done().buffer.asUint8List();

    final InputImageMetadata metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  static InputImageFormat? _inputImageFormat(int rawFormat) {
    switch (rawFormat) {
      // Android YUV_420_888
      case 35:
        return InputImageFormat.yuv420;
      // iOS kCVPixelFormatType_32BGRA
      case 1111970369:
        return InputImageFormat.bgra8888;
      // Android NV21 (some devices)
      case 17:
        return InputImageFormat.nv21;
      default:
        return null;
    }
  }
}
