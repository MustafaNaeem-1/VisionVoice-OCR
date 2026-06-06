import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/recognition_language.dart';
import '../utils/image_utils.dart';

typedef OnTextRecognized = void Function(String text, List<TextBlock> blocks);
typedef OnError = void Function(String error);

class CameraService {
  CameraService({
    required this.onTextRecognized,
    required this.onError,
    this.processIntervalMs = 700,
  });

  final OnTextRecognized onTextRecognized;
  final OnError onError;
  final int processIntervalMs;

  CameraController? _controller;
  final TextRecognizer _latinRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  RecognitionLanguage _language = RecognitionLanguage.english;
  bool _isProcessing = false;
  bool _isStreaming = false;
  bool _torchEnabled = false;
  bool _reportedMissingUrduModel = false;
  DateTime _lastProcessTime = DateTime(0);
  DateTime _lastAutoLatinFrame = DateTime(0);

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isTorchEnabled => _torchEnabled;
  RecognitionLanguage get language => _language;

  bool get isUrduOcrAvailable => false;

  Future<void> initialize() async {
    final List<CameraDescription> cameras = await availableCameras();
    if (cameras.isEmpty) {
      onError('No cameras found on this device.');
      return;
    }

    final CameraDescription camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup:
          defaultTargetPlatform == TargetPlatform.iOS
              ? ImageFormatGroup.bgra8888
              : ImageFormatGroup.nv21,
    );

    try {
      await _controller!.initialize();
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await _controller!.setFlashMode(FlashMode.off);
    } catch (e) {
      onError('Camera initialization failed: $e');
    }
  }

  Future<void> setLanguage(RecognitionLanguage language) async {
    _language = language;
    _reportedMissingUrduModel = false;
    _lastProcessTime = DateTime(0);
  }

  Future<void> startStream() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isStreaming) return;
    _isStreaming = true;
    await _controller!.startImageStream(_onCameraImage);
  }

  Future<void> stopStream() async {
    if (!_isStreaming || _controller == null) return;
    _isStreaming = false;
    try {
      await _controller!.stopImageStream();
    } catch (_) {}
  }

  Future<void> resumeStream() async {
    if (_isStreaming) return;
    await startStream();
  }

  Future<bool> toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return false;

    try {
      _torchEnabled = !_torchEnabled;
      await controller.setFlashMode(
        _torchEnabled ? FlashMode.torch : FlashMode.off,
      );
      return _torchEnabled;
    } catch (e) {
      _torchEnabled = false;
      onError('Flash is not available on this camera.');
      return false;
    }
  }

  void _onCameraImage(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastProcessTime).inMilliseconds < processIntervalMs) {
      return;
    }
    _lastProcessTime = now;

    if (_isProcessing) return;
    _isProcessing = true;
    _processImage(image).whenComplete(() => _isProcessing = false);
  }

  Future<void> _processImage(CameraImage image) async {
    if (_controller == null) return;
    if (_language == RecognitionLanguage.urdu && !isUrduOcrAvailable) {
      _reportMissingUrduRecognizer();
      onTextRecognized('', const []);
      return;
    }

    final InputImage? inputImage = ImageUtils.fromCameraImage(
      image: image,
      camera: _controller!.description,
      deviceOrientation: DeviceOrientation.portraitUp,
    );
    if (inputImage == null) return;

    try {
      final RecognizedText recognizedText = await _recognizeForMode(inputImage);
      onTextRecognized(recognizedText.text, recognizedText.blocks);
    } catch (e) {
      debugPrint('OCR frame error: $e');
    }
  }

  Future<RecognizedText> _recognizeForMode(InputImage inputImage) async {
    if (_language == RecognitionLanguage.auto) {
      final now = DateTime.now();
      if (now.difference(_lastAutoLatinFrame).inMilliseconds <
          processIntervalMs * 2) {
        return RecognizedText(text: '', blocks: const []);
      }
      _lastAutoLatinFrame = now;
      return _latinRecognizer.processImage(inputImage);
    }

    return _latinRecognizer.processImage(inputImage);
  }

  Future<RecognizedText?> captureAndRecognize({
    RecognitionLanguage? language,
  }) async {
    if (_controller == null || !_controller!.value.isInitialized) return null;

    final mode = language ?? _language;
    if (mode == RecognitionLanguage.urdu && !isUrduOcrAvailable) {
      _reportMissingUrduRecognizer();
      return RecognizedText(text: '', blocks: const []);
    }

    try {
      final XFile file = await _controller!.takePicture();
      final InputImage inputImage = InputImage.fromFilePath(file.path);
      return _latinRecognizer.processImage(inputImage);
    } catch (e) {
      onError('Capture failed: $e');
      return null;
    }
  }

  void _reportMissingUrduRecognizer() {
    if (_reportedMissingUrduModel) return;
    _reportedMissingUrduModel = true;
    onError(
      'Urdu OCR needs an Arabic-script recognizer. The installed Google ML Kit Flutter package does not expose one yet.',
    );
  }

  Future<void> dispose() async {
    _isStreaming = false;
    await _latinRecognizer.close();
    await _controller?.stopImageStream().catchError((_) {});
    await _controller?.dispose();
    _controller = null;
  }
}
