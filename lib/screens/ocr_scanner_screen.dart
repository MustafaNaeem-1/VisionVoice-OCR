import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:vibration/vibration.dart';
import '../models/recognition_language.dart';
import '../services/camera_service.dart';
import '../services/tts_service.dart';
import '../widgets/detected_text_panel.dart';
import '../widgets/scan_mode_indicator.dart';
import '../widgets/text_overlay_painter.dart';

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
  late AnimationController _scanLineController;
  late AnimationController _holdController;
  late Animation<double> _scanLine;
  late Animation<double> _holdScale;

  RecognitionLanguage _language = RecognitionLanguage.english;
  ScannerStatus _status = ScannerStatus.initializing;
  ScanMode _mode = ScanMode.live;
  String _detectedText = '';
  String _errorMessage = '';
  List<TextBlock> _textBlocks = [];
  bool _isInitialized = false;
  bool _isTtsEnabled = true;
  bool _isSpeaking = false;
  bool _isCapturing = false;
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
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
    _scanLine = CurvedAnimation(
      parent: _scanLineController,
      curve: Curves.easeInOut,
    );

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

    final trimmed = text.trim();
    setState(() {
      _detectedText = trimmed;
      _textBlocks = blocks;
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
    if (!mounted) return;
    setState(() {
      _language = language;
      _detectedText = '';
      _textBlocks = [];
      _errorMessage =
          language == RecognitionLanguage.urdu
              ? 'Urdu speech is enabled. Urdu OCR needs an Arabic-script ML Kit model that this Flutter plugin does not expose.'
              : '';
      _status =
          language == RecognitionLanguage.urdu
              ? ScannerStatus.error
              : ScannerStatus.idle;
    });
  }

  Future<void> _onHoldStart() async {
    if (!_isInitialized || _isCapturing) return;
    _isHolding = true;
    _holdController.forward();
    await _vibrate(duration: 70);
    await _ttsService.stop();
    await _cameraService.stopStream();

    setState(() {
      _mode = ScanMode.frozen;
      _status = ScannerStatus.scanning;
      _isCapturing = true;
      _errorMessage = '';
    });

    final RecognizedText? result = await _cameraService.captureAndRecognize(
      language: _language,
    );
    if (!mounted) return;

    final text = result?.text.trim() ?? '';
    setState(() {
      _detectedText = text;
      _textBlocks = result?.blocks ?? [];
      _isCapturing = false;
      _status =
          text.isEmpty ? ScannerStatus.noText : ScannerStatus.textDetected;
      _panelExpanded = text.length > 120;
    });

    await _vibrate(duration: text.isEmpty ? 30 : 90);
    if (_isTtsEnabled && text.isNotEmpty) {
      await _ttsService.speakNow(text, language: _language);
    }
  }

  Future<void> _onHoldEnd() async {
    if (!_isHolding) return;
    _isHolding = false;
    _holdController.reverse();
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() {
      _mode = ScanMode.live;
      if (_status != ScannerStatus.error) _status = ScannerStatus.idle;
    });
    await _cameraService.resumeStream();
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
    await _ttsService.speakNow(_detectedText, language: _language);
  }

  Future<void> _vibrate({int duration = 50}) async {
    HapticFeedback.selectionClick();
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: duration);
    }
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _holdController.dispose();
    unawaited(_ttsService.dispose());
    unawaited(_cameraService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A12),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraLayer(),
          _buildScrims(),
          if (_isInitialized && _textBlocks.isNotEmpty) _buildTextOverlay(),
          if (_isInitialized) _buildScannerFrame(),
          SafeArea(child: _buildTopBar()),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildBottomDock(),
            ),
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

  Widget _buildScrims() {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: 0.22,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.42),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.30,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.52),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1020).withValues(alpha: 0.56),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              borderRadius: BorderRadius.circular(20),
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
                Flexible(
                  flex: 0,
                  child: _TopButton(
                    label: _language.shortLabel,
                    icon: Icons.translate_rounded,
                    onTap: _showLanguageSheet,
                  ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildTextOverlay() {
    final controller = _cameraService.controller!;
    return CustomPaint(
      painter: TextOverlayPainter(
        blocks: _textBlocks,
        previewSize: Size(
          controller.value.previewSize?.width ?? 0,
          controller.value.previewSize?.height ?? 0,
        ),
        isFrozen: _mode == ScanMode.frozen,
      ),
    );
  }

  Widget _buildScannerFrame() {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.82,
          heightFactor: 0.48,
          child: Stack(
            children: [
              CustomPaint(painter: _CornerGuidePainter()),
              if (_mode == ScanMode.live)
                AnimatedBuilder(
                  animation: _scanLine,
                  builder: (context, _) {
                    return Align(
                      alignment: Alignment(0, -1 + (_scanLine.value * 2)),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFF38D7FF).withValues(alpha: 0.85),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomDock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ScanModeIndicator(status: _status, language: _language),
            ),
          DetectedTextPanel(
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
          const SizedBox(height: 10),
          Row(
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
                icon:
                    _isTorchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                label: _isTorchOn ? 'Flash on' : 'Flash off',
                active: _isTorchOn,
                onTap: _isInitialized ? _toggleTorch : null,
              ),
            ],
          ),
        ],
      ),
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
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF38D7FF), Color(0xFF7A6BFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38D7FF).withValues(alpha: 0.34),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
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
        return 'Latin OCR with en-US speech';
      case RecognitionLanguage.urdu:
        return 'Urdu speech with ur-PK. OCR model unavailable in current ML Kit plugin.';
      case RecognitionLanguage.auto:
        return 'Live English OCR now; Urdu speech is used when Arabic-script text is present.';
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
      child: ListTile(
        onTap: onTap,
        selected: selected,
        minVerticalPadding: 14,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        tileColor: const Color(0xFF1A2232),
        selectedTileColor: const Color(0xFF20324A),
        leading: CircleAvatar(
          backgroundColor:
              selected ? const Color(0xFF38D7FF) : const Color(0xFF2A3548),
          child: Text(
            language.shortLabel,
            style: TextStyle(
              color:
                  selected ? const Color(0xFF07111E) : const Color(0xFFDDE7F6),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          language.label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitle),
        trailing:
            selected
                ? const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF55E6A5),
                )
                : null,
      ),
    );
  }
}

class _CornerGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFFE8F8FF).withValues(alpha: 0.68)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    const corner = 34.0;
    const inset = 2.0;

    void drawCorner(Offset a, Offset b, Offset c) {
      canvas.drawLine(a, b, paint);
      canvas.drawLine(a, c, paint);
    }

    drawCorner(
      const Offset(inset, inset),
      const Offset(corner, inset),
      const Offset(inset, corner),
    );
    drawCorner(
      Offset(size.width - inset, inset),
      Offset(size.width - corner, inset),
      Offset(size.width - inset, corner),
    );
    drawCorner(
      Offset(inset, size.height - inset),
      Offset(corner, size.height - inset),
      Offset(inset, size.height - corner),
    );
    drawCorner(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - corner, size.height - inset),
      Offset(size.width - inset, size.height - corner),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
