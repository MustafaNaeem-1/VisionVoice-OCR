import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:vibration/vibration.dart';
import '../models/recognition_language.dart';
import '../services/camera_service.dart';
import '../services/google_vision_urdu_ocr_service.dart';
import '../services/tts_service.dart';
import '../widgets/detected_text_panel.dart';

enum ScanMode { live, frozen }

class OCRScannerScreen extends StatefulWidget {
  const OCRScannerScreen({super.key});

  @override
  State<OCRScannerScreen> createState() => _OCRScannerScreenState();
}

class _OCRScannerScreenState extends State<OCRScannerScreen>
    with TickerProviderStateMixin {
  late CameraService _cameraService;
  late TtsService _ttsService;
  final GoogleVisionUrduOcrService _googleVisionUrduOcrService =
      GoogleVisionUrduOcrService();
  late AnimationController _holdController;
  late Animation<double> _holdScale;

  RecognitionLanguage _language = RecognitionLanguage.english;
  ScannerStatus _status = ScannerStatus.initializing;
  ScanMode _mode = ScanMode.live;
  String _detectedText = '';
  String _errorMessage = '';
  bool _isInitialized = false;
  bool _isTtsEnabled = true;
  bool _isSpeaking = false;
  bool _isCapturing = false;
  bool _isScanning = false;
  bool _isHolding = false;
  bool _isTorchOn = false;
  bool _panelExpanded = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initServices();
  }

  void _initAnimations() {
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _holdScale = Tween(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _holdController, curve: Curves.easeOut));
  }

  Future<void> _initServices() async {
    _ttsService = TtsService(
      onStateChanged: (speaking) {
        if (!mounted) return;
        setState(() {
          _isSpeaking = speaking;
          if (speaking) _status = ScannerStatus.speaking;
        });
      },
    );
    _cameraService = CameraService(
      onTextRecognized: _onTextRecognized,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = error;
          _status = ScannerStatus.error;
        });
      },
    );

    await _ttsService.initialize();
    await _cameraService.initialize();
    if (!_cameraService.isInitialized) {
      if (mounted) setState(() => _status = ScannerStatus.error);
      return;
    }

    await _cameraService.startStream();
    if (!mounted) return;
    setState(() {
      _isInitialized = true;
      _status = ScannerStatus.idle;
    });
  }

  void _onTextRecognized(String text, List<TextBlock> blocks) {
    if (!mounted || _mode == ScanMode.frozen) return;
    if (_language != RecognitionLanguage.english) return;

    final trimmed = text.trim();
    setState(() {
      _detectedText = trimmed;
      if (_status != ScannerStatus.error || trimmed.isNotEmpty) {
        _status =
            trimmed.isEmpty ? ScannerStatus.noText : ScannerStatus.textDetected;
      }
    });

    if (_isTtsEnabled && trimmed.isNotEmpty) {
      _ttsService.smartSpeak(trimmed, language: _language);
    }
  }

  Future<void> _changeLanguage(RecognitionLanguage language) async {
    if (_language == language) return;
    await _vibrate(duration: 45);
    await _ttsService.stop();
    await _ttsService.setLanguage(language);
    await _cameraService.setLanguage(language);
    if (language == RecognitionLanguage.english && _isInitialized) {
      await _cameraService.resumeStream();
    } else {
      await _cameraService.stopStream();
    }
    if (!mounted) return;
    setState(() {
      _language = language;
      _detectedText = '';
      _errorMessage = '';
      _status = ScannerStatus.idle;
    });
  }

  Future<void> _onHoldStart() async {
    if (!_isInitialized || _isScanning) return;
    _isHolding = true;
    _isScanning = true;
    _holdController.forward();
    await _vibrate(duration: 70);
    await _ttsService.stop();
    await _cameraService.stopStream();

    setState(() {
      _mode = ScanMode.frozen;
      _status =
          _language == RecognitionLanguage.urdu
              ? ScannerStatus.readingUrdu
              : ScannerStatus.scanning;
      _isCapturing = true;
      _errorMessage = '';
      _detectedText = '';
    });

    String text = '';
    bool hasOcrError = false;
    try {
      switch (_language) {
        case RecognitionLanguage.urdu:
          text = await _captureAndRecognizeUrdu();
          break;
        case RecognitionLanguage.auto:
          text = await _captureAndRecognizeAuto();
          break;
        case RecognitionLanguage.english:
          text = await _captureAndRecognizeEnglish();
          break;
      }
    } catch (error) {
      hasOcrError = true;
      text = '';
      if (mounted) {
        setState(() {
          _errorMessage = 'Scan failed: $error';
          _status = ScannerStatus.error;
        });
      }
    }

    if (!mounted) return;
    final displayText =
        _language == RecognitionLanguage.urdu && text.isEmpty && !hasOcrError
            ? _googleVisionUrduOcrService.lastErrorMessage.isNotEmpty
                ? _googleVisionUrduOcrService.lastErrorMessage
                : GoogleVisionUrduOcrService.noTextMessage
            : text;
    setState(() {
      _detectedText = displayText;
      _isCapturing = false;
      _isScanning = false;
      _mode = ScanMode.live;
      _status =
          hasOcrError
              ? ScannerStatus.error
              : text.isEmpty
              ? ScannerStatus.noText
              : _language == RecognitionLanguage.urdu ||
                  (_language == RecognitionLanguage.auto && _containsUrdu(text))
              ? ScannerStatus.urduTextDetected
              : ScannerStatus.textDetected;
      _panelExpanded = displayText.length > 120;
    });

    final shouldSpeakDetectedText = displayText == text && text.isNotEmpty;
    await _vibrate(duration: text.isEmpty ? 30 : 90);
    try {
      if (_isTtsEnabled && shouldSpeakDetectedText) {
        await _speakDetectedText(text);
      }
    } on TtsVoiceUnavailableException catch (error) {
      debugPrint('Urdu TTS unavailable after scan');
      if (mounted) _showUrduTtsUnavailableMessage(error.message);
    } catch (error) {
      debugPrint('TTS failed after scan: $error');
      if (mounted) setState(() => _isSpeaking = false);
    } finally {
      if (_language == RecognitionLanguage.english) {
        await _cameraService.resumeStream();
      }
    }
  }

  Future<void> _onHoldEnd() async {
    if (!_isHolding) return;
    _isHolding = false;
    _holdController.reverse();
  }

  Future<String> _captureAndRecognizeEnglish() async {
    final RecognizedText? result = await _cameraService.captureAndRecognize(
      language: _language,
    );
    return result?.text.trim() ?? '';
  }

  Future<String> _captureAndRecognizeUrdu() async {
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) return '';

    final XFile image = await controller.takePicture();
    try {
      return await _googleVisionUrduOcrService.recognizeUrduFromImagePath(
        image.path,
      );
    } finally {
      try {
        final file = File(image.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  Future<String> _captureAndRecognizeAuto() async {
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) return '';

    final XFile image = await controller.takePicture();
    final TextRecognizer textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    try {
      final urduText =
          (await _googleVisionUrduOcrService.recognizeUrduFromImagePath(
            image.path,
          )).trim();
      if (urduText.isNotEmpty && _containsUrdu(urduText)) {
        return urduText;
      }

      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } finally {
      await textRecognizer.close();
      try {
        final file = File(image.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  bool _containsUrdu(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  Future<void> _toggleTts() async {
    await _vibrate(duration: 35);
    setState(() => _isTtsEnabled = !_isTtsEnabled);
    if (!_isTtsEnabled) await _ttsService.stop();
  }

  Future<void> _toggleTorch() async {
    await _vibrate(duration: 35);
    final enabled = await _cameraService.toggleTorch();
    if (mounted) setState(() => _isTorchOn = enabled);
  }

  Future<void> _stopSpeech() async {
    await _vibrate(duration: 45);
    await _ttsService.stop();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      if (_status == ScannerStatus.speaking) _status = ScannerStatus.idle;
    });
  }

  Future<void> _reread() async {
    if (_detectedText.isEmpty) {
      await _vibrate(duration: 25);
      setState(() => _status = ScannerStatus.noText);
      return;
    }
    await _vibrate(duration: 45);
    try {
      await _speakDetectedText(_detectedText);
    } on TtsVoiceUnavailableException catch (error) {
      debugPrint('Urdu TTS unavailable on re-read');
      if (mounted) _showUrduTtsUnavailableMessage(error.message);
    }
  }

  Future<void> _speakDetectedText(String text) async {
    if (_language == RecognitionLanguage.urdu ||
        (_language == RecognitionLanguage.auto && _containsUrdu(text))) {
      await _ttsService.speakUrdu(text);
      return;
    }

    await _ttsService.speakNow(text, language: RecognitionLanguage.english);
  }

  void _showUrduTtsUnavailableMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Open TTS Settings',
          onPressed: () => unawaited(_ttsService.openTtsSettings()),
        ),
      ),
    );
  }

  Future<void> _vibrate({int duration = 50}) async {
    HapticFeedback.selectionClick();
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: duration);
    }
  }

  @override
  void dispose() {
    _holdController.dispose();
    unawaited(_ttsService.dispose());
    unawaited(_cameraService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.viewPaddingOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFF080A12),
      body: Stack(
        children: [
          Positioned.fill(child: _buildCameraLayer()),
          Positioned(
            top: safeArea.top + 12,
            left: 16,
            right: 16,
            child: _buildTopBar(),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 120,
            child: DetectedTextPanel(
              text:
                  _errorMessage.isNotEmpty && _detectedText.isEmpty
                      ? _errorMessage
                      : _detectedText,
              status: _status,
              language: _language,
              isExpanded: _panelExpanded,
              onToggleExpanded:
                  () => setState(() => _panelExpanded = !_panelExpanded),
              isSpeaking: _isSpeaking,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: safeArea.bottom + 16,
            child: _buildActionButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (!_isInitialized || _cameraService.controller == null) {
      return Container(
        color: const Color(0xFF0B1020),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF38D7FF)),
              const SizedBox(height: 18),
              Text(
                _errorMessage.isEmpty ? _status.label : _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFDDE7F6), fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _cameraService.controller!;
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return OverflowBox(
            maxWidth: constraints.maxWidth,
            maxHeight: constraints.maxHeight,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize.height,
                height: previewSize.width,
                child: CameraPreview(controller),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(8, 10, 18, 0.58),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.14)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.visibility_rounded,
            color: Color(0xFF38D7FF),
            size: 24,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'VisionVoice',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFF6F9FF),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _TopButton(
            label: _language.shortLabel,
            icon: Icons.translate_rounded,
            onTap: _showLanguageSheet,
          ),
          const SizedBox(width: 6),
          _IconCircle(
            icon:
                _isTtsEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
            label: _isTtsEnabled ? 'Sound on' : 'Sound off',
            active: _isTtsEnabled,
            onTap: _toggleTts,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.replay_rounded,
            label: 'Re-read',
            onTap: _detectedText.isEmpty ? null : _reread,
          ),
        ),
        const SizedBox(width: 8),
        ScaleTransition(scale: _holdScale, child: _buildHoldButton()),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.stop_rounded,
            label: 'Stop',
            danger: true,
            onTap: _stopSpeech,
          ),
        ),
        const SizedBox(width: 8),
        _IconCircle(
          icon: _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
          label: _isTorchOn ? 'Flash on' : 'Flash off',
          active: _isTorchOn,
          onTap: _isInitialized ? _toggleTorch : null,
        ),
      ],
    );
  }

  Widget _buildHoldButton() {
    return Semantics(
      button: true,
      label: _isCapturing ? 'Scanning' : 'Hold to scan',
      child: GestureDetector(
        onTapDown: (_) => _onHoldStart(),
        onTapUp: (_) => _onHoldEnd(),
        onTapCancel: _onHoldEnd,
        child: SizedBox(
          width: 82,
          height: 82,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF38D7FF),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isCapturing
                      ? Icons.hourglass_top_rounded
                      : Icons.center_focus_strong_rounded,
                  color: Colors.white,
                  size: 31,
                ),
                const SizedBox(height: 4),
                Text(
                  _isCapturing ? 'Scan' : 'Hold',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguageSheet() async {
    await _vibrate(duration: 25);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111622),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final sheetHeight = MediaQuery.sizeOf(context).height * 0.62;
        return SafeArea(
          child: SizedBox(
            height: sheetHeight,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              physics: const BouncingScrollPhysics(),
              children: [
                const Text(
                  'Recognition Language',
                  style: TextStyle(
                    color: Color(0xFFF6F9FF),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                for (final option in RecognitionLanguage.values)
                  _LanguageOption(
                    language: option,
                    selected: option == _language,
                    subtitle: _subtitleForLanguage(option),
                    onTap: () {
                      Navigator.pop(context);
                      _changeLanguage(option);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _subtitleForLanguage(RecognitionLanguage language) {
    switch (language) {
      case RecognitionLanguage.english:
        return 'English OCR with en-US speech';
      case RecognitionLanguage.urdu:
        return 'Urdu OCR with ur-PK speech.';
      case RecognitionLanguage.auto:
        return 'Automatically detects language.';
    }
  }
}

class _TopButton extends StatelessWidget {
  const _TopButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Language selector, $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFF6F9FF), size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  color: Color(0xFFF6F9FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF38D7FF) : const Color(0xFFDDE7F6);
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: onTap,
        tooltip: label,
        icon: Icon(icon, color: color),
        style: IconButton.styleFrom(
          minimumSize: const Size(52, 52),
          backgroundColor: Colors.white.withValues(alpha: active ? 0.13 : 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF8A96) : const Color(0xFFDDE7F6);
    return Semantics(
      button: true,
      label: label,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.10),
          foregroundColor: color,
          minimumSize: const Size(72, 62),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.selected,
    required this.subtitle,
    required this.onTap,
  });

  final RecognitionLanguage language;
  final bool selected;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFF20324A) : const Color(0xFF1A2232),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          selected
                              ? const Color(0xFF38D7FF)
                              : const Color(0xFF2A3548),
                    ),
                    child: Center(
                      child: Text(
                        language.shortLabel,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          color:
                              selected
                                  ? const Color(0xFF07111E)
                                  : const Color(0xFFDDE7F6),
                          fontSize:
                              language == RecognitionLanguage.auto ? 13 : 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        language.label,
                        style: const TextStyle(
                          color: Color(0xFFF6F9FF),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFB7C0D3),
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF55E6A5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
