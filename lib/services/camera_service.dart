import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../utils/image_utils.dart';

/// Callback types
typedef OnTextRecognized = void Function(String text, List<TextBlock> blocks);
typedef OnError = void Function(String error);

/// Manages camera lifecycle, frame streaming, and ML Kit text recognition.
/// Exposes [onTextRecognized] callback for new results and applies a
/// debounce to process ≈2-3 frames per second.
class CameraService {
  CameraService({
    required this.onTextRecognized,
    required this.onError,
    this.processIntervalMs = 400, // ~2.5 fps
  });

  final OnTextRecognized onTextRecognized;
  final OnError onError;
  final int processIntervalMs;

  CameraController? _controller;
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  bool _isProcessing = false;
  DateTime _lastProcessTime = DateTime(0);
  bool _isStreaming = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  // ── Initialization ──────────────────────────────────────────────────────────

  /// Call once to open the back camera and start the image stream.
  Future<void> initialize() async {
    final List<CameraDescription> cameras = await availableCameras();
    if (cameras.isEmpty) {
      onError('No cameras found on this device.');
      return;
    }

    // Prefer rear camera for OCR
    final CameraDescription camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21,
    );

    try {
      await _controller!.initialize();
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (e) {
      onError('Camera initialization failed: $e');
      return;
    }
  }

  // ── Streaming ───────────────────────────────────────────────────────────────

  /// Starts the live image stream feeding frames into ML Kit.
  Future<void> startStream() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isStreaming) return;
    _isStreaming = true;

    await _controller!.startImageStream(_onCameraImage);
  }

  /// Stops the live image stream (e.g. while "Hold to Scan" is active).
  Future<void> stopStream() async {
    if (!_isStreaming) return;
    _isStreaming = false;
    try {
      await _controller!.stopImageStream();
    } catch (_) {}
  }

  /// Resumes the stream after being stopped.
  Future<void> resumeStream() async {
    if (_isStreaming) return;
    await startStream();
  }

  // ── Frame Processing ────────────────────────────────────────────────────────

  void _onCameraImage(CameraImage image) {
    // Debounce: skip frames that arrive too fast
    final now = DateTime.now();
    if (now.difference(_lastProcessTime).inMilliseconds < processIntervalMs) {
      return;
    }
    _lastProcessTime = now;

    // Prevent concurrent processing
    if (_isProcessing) return;
    _isProcessing = true;

    // Process on a separate isolate-friendly async call
    _processImage(image).whenComplete(() => _isProcessing = false);
  }

  Future<void> _processImage(CameraImage image) async {
    if (_controller == null) return;

    final InputImage? inputImage = ImageUtils.fromCameraImage(
      image: image,
      camera: _controller!.description,
      deviceOrientation: DeviceOrientation.portraitUp,
    );
    if (inputImage == null) return;

    try {
      final RecognizedText recognizedText =
          await _recognizer.processImage(inputImage);
      onTextRecognized(recognizedText.text, recognizedText.blocks);
    } catch (e) {
      // Silent errors on individual frames are acceptable
      debugPrint('OCR frame error: $e');
    }
  }

  // ── Single-Frame Capture (Hold to Scan) ────────────────────────────────────

  /// Captures a still image and runs OCR on it for high-accuracy scanning.
  Future<RecognizedText?> captureAndRecognize() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;

    try {
      final XFile file = await _controller!.takePicture();
      final InputImage inputImage = InputImage.fromFilePath(file.path);
      return await _recognizer.processImage(inputImage);
    } catch (e) {
      onError('Capture failed: $e');
      return null;
    }
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    _isStreaming = false;
    await _recognizer.close();
    await _controller?.stopImageStream().catchError((_) {});
    await _controller?.dispose();
    _controller = null;
  }
}
