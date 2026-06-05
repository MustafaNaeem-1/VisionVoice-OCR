import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:vibration/vibration.dart';
import '../services/camera_service.dart';
import '../services/tts_service.dart';
import '../widgets/text_overlay_painter.dart';
import '../widgets/scan_mode_indicator.dart';
import '../widgets/detected_text_panel.dart';

enum ScanMode { live, frozen }

/// The main OCR + TTS scanning screen.
///
/// Features:
///  • Live camera preview with bounding-box overlay
///  • 2-3 fps debounced OCR via [CameraService]
///  • Smart TTS that only speaks on text changes
///  • "Hold to Scan" button for high-accuracy still-frame capture
///  • Haptic feedback, large tappable areas, high-contrast accessible UI
class OCRScannerScreen extends StatefulWidget {
  const OCRScannerScreen({super.key});

  @override
  State<OCRScannerScreen> createState() => _OCRScannerScreenState();
}

class _OCRScannerScreenState extends State<OCRScannerScreen>
    with TickerProviderStateMixin {
  // ── Services ────────────────────────────────────────────────────────────────
  late CameraService _cameraService;
  final TtsService _ttsService = TtsService();

  // ── State ────────────────────────────────────────────────────────────────────
  ScanMode _mode = ScanMode.live;
  String _detectedText = '';
  List<TextBlock> _textBlocks = [];
  bool _isInitialized = false;
  bool _isTtsEnabled = true;
  bool _isHolding = false;
  bool _isCapturing = false;
  String _statusMessage = 'Initializing camera…';
  String _errorMessage = '';

  // ── Animation Controllers ────────────────────────────────────────────────────
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnim;
  late AnimationController _holdButtonController;
  late Animation<double> _holdScale;
  late AnimationController _pulseController;
  late Animation<double> _pulseOpacity;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initServices();
  }

  void _initAnimations() {
    // Scanning line animation
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    // Hold button scale
    _holdButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _holdScale = Tween(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _holdButtonController, curve: Curves.easeIn),
    );

    // Pulse for active TTS indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseOpacity = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initServices() async {
    await _ttsService.initialize();

    _cameraService = CameraService(
      onTextRecognized: _onTextRecognized,
      onError: (error) {
        if (mounted) setState(() => _errorMessage = error);
      },
    );

    await _cameraService.initialize();

    if (_cameraService.isInitialized) {
      await _cameraService.startStream();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Point camera at text';
        });
      }
    } else {
      if (mounted) {
        setState(() => _statusMessage = 'Camera initialization failed');
      }
    }
  }

  // ── OCR Callback ─────────────────────────────────────────────────────────────

  void _onTextRecognized(String text, List<TextBlock> blocks) {
    if (!mounted) return;
    if (_mode == ScanMode.frozen) return; // Don't update while frozen

    setState(() {
      _detectedText = text;
      _textBlocks = blocks;
      _statusMessage = text.isEmpty ? 'No text detected' : 'Text detected';
    });

    // Smart TTS: speak only if text changed
    if (_isTtsEnabled && text.isNotEmpty) {
      _ttsService.smartSpeak(text);
    }
  }

  // ── Hold to Scan ─────────────────────────────────────────────────────────────

  Future<void> _onHoldStart() async {
    if (_isCapturing) return;
    _isHolding = true;
    _holdButtonController.forward();

    // Haptic feedback
    _vibrate(duration: 80);

    // Freeze live updates and stop TTS
    await _ttsService.stop();
    await _cameraService.stopStream();

    setState(() {
      _mode = ScanMode.frozen;
      _statusMessage = 'Scanning…';
      _isCapturing = true;
    });

    // Capture high-res still and run OCR
    final RecognizedText? result = await _cameraService.captureAndRecognize();

    if (result != null && mounted) {
      final String fullText = result.text;
      setState(() {
        _detectedText = fullText;
        _textBlocks = result.blocks;
        _statusMessage = fullText.isEmpty
            ? 'No text found in frame'
            : 'Hold released – reading aloud…';
        _isCapturing = false;
      });

      // Force-speak the full captured text
      if (_isTtsEnabled && fullText.isNotEmpty) {
        await _ttsService.speakNow(fullText);
      }
    } else if (mounted) {
      setState(() {
        _statusMessage = 'Capture failed – try again';
        _isCapturing = false;
      });
    }
  }

  Future<void> _onHoldEnd() async {
    if (!_isHolding) return;
    _isHolding = false;
    _holdButtonController.reverse();

    // Resume live scanning after a short delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _mode = ScanMode.live;
        _statusMessage = 'Point camera at text';
      });
      await _cameraService.resumeStream();
    }
  }

  // ── TTS Toggle ───────────────────────────────────────────────────────────────

  Future<void> _toggleTts() async {
    _vibrate(duration: 40);
    setState(() => _isTtsEnabled = !_isTtsEnabled);
    if (!_isTtsEnabled) await _ttsService.stop();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Future<void> _vibrate({int duration = 50}) async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: duration);
    }
  }

  @override
  Future<void> dispose() async {
    _scanLineController.dispose();
    _holdButtonController.dispose();
    _pulseController.dispose();
    await _ttsService.dispose();
    await _cameraService.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildCameraArea()),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
              ),
            ),
            child: const Icon(Icons.visibility_rounded,
                size: 22, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text(
            'VisionVoice',
            style: TextStyle(
              color: Color(0xFFE8E8F0),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),

          // Mode indicator
          ScanModeIndicator(mode: _mode),

          const SizedBox(width: 12),

          // TTS toggle button
          GestureDetector(
            onTap: _toggleTts,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isTtsEnabled
                    ? const Color(0xFF00D4FF).withOpacity(0.15)
                    : const Color(0xFF2A2A35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isTtsEnabled
                      ? const Color(0xFF00D4FF).withOpacity(0.5)
                      : const Color(0xFF3A3A45),
                  width: 1.5,
                ),
              ),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) => Opacity(
                  opacity: _isTtsEnabled
                      ? _pulseOpacity.value
                      : 1.0,
                  child: child,
                ),
                child: Icon(
                  _isTtsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: _isTtsEnabled
                      ? const Color(0xFF00D4FF)
                      : const Color(0xFF666680),
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Camera Preview + Overlay ─────────────────────────────────────────────────

  Widget _buildCameraArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _mode == ScanMode.frozen
                  ? const Color(0xFFFFD700).withOpacity(0.7)
                  : const Color(0xFF00D4FF).withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              // Camera preview
              if (_isInitialized &&
                  _cameraService.controller != null)
                _buildCameraPreview()
              else
                _buildCameraPlaceholder(),

              // Bounding box overlay
              if (_isInitialized && _textBlocks.isNotEmpty)
                _buildTextOverlay(),

              // Animated scan line (live mode only)
              if (_mode == ScanMode.live && _isInitialized)
                _buildScanLine(),

              // Frozen frame indicator
              if (_mode == ScanMode.frozen)
                _buildFrozenOverlay(),

              // Status chip at bottom of camera
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(child: _buildStatusChip()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraService.controller!;
    final double aspectRatio = controller.value.aspectRatio;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: CameraPreview(controller),
    );
  }

  Widget _buildCameraPlaceholder() {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        color: const Color(0xFF0D0D1A),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_errorMessage.isNotEmpty) ...[
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFF5F6D), size: 56),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFF5F6D), fontSize: 15),
                ),
              ),
            ] else ...[
              const CircularProgressIndicator(
                color: Color(0xFF00D4FF),
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: const TextStyle(
                    color: Color(0xFFAAAAAC), fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextOverlay() {
    final controller = _cameraService.controller!;
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: TextOverlayPainter(
            blocks: _textBlocks,
            previewSize: Size(
              controller.value.previewSize?.width ?? 0,
              controller.value.previewSize?.height ?? 0,
            ),
            isFrozen: _mode == ScanMode.frozen,
          ),
        );
      },
    );
  }

  Widget _buildScanLine() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _scanLineAnim,
        builder: (_, _) {
          return Align(
            alignment: Alignment(0.0, -1.0 + (_scanLineAnim.value * 2.0)),
            child: Container(
              height: 2,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF00D4FF).withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFrozenOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          border: Border.all(color: const Color(0xFFFFD700), width: 2),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.lock_rounded,
                color: Color(0xFFFFD700), size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _mode == ScanMode.frozen
              ? const Color(0xFFFFD700).withOpacity(0.5)
              : const Color(0xFF00D4FF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _mode == ScanMode.frozen
                  ? const Color(0xFFFFD700)
                  : (_detectedText.isNotEmpty
                      ? const Color(0xFF00FF88)
                      : const Color(0xFF666680)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _statusMessage,
            style: const TextStyle(
              color: Color(0xFFE8E8F0),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Panel ─────────────────────────────────────────────────────────────

  Widget _buildBottomPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Detected text panel
        DetectedTextPanel(
          text: _detectedText,
          isEmpty: _detectedText.isEmpty,
        ),

        const SizedBox(height: 16),

        // Control bar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              // Re-read last text button
              Expanded(
                child: _buildIconButton(
                  icon: Icons.replay_rounded,
                  label: 'Re-read',
                  onTap: () {
                    _vibrate(duration: 40);
                    if (_detectedText.isNotEmpty) {
                      _ttsService.speakNow(_detectedText);
                    }
                  },
                ),
              ),

              const SizedBox(width: 16),

              // Hold to Scan (center, larger)
              _buildHoldToScanButton(),

              const SizedBox(width: 16),

              // Stop speech button
              Expanded(
                child: _buildIconButton(
                  icon: Icons.stop_circle_rounded,
                  label: 'Stop',
                  onTap: () {
                    _vibrate(duration: 40);
                    _ttsService.stop();
                  },
                  isDestructive: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final Color color = isDestructive
        ? const Color(0xFFFF5F6D)
        : const Color(0xFF00D4FF);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldToScanButton() {
    return GestureDetector(
      onTapDown: (_) => _onHoldStart(),
      onTapUp: (_) => _onHoldEnd(),
      onTapCancel: _onHoldEnd,
      child: ScaleTransition(
        scale: _holdScale,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isCapturing
                  ? [const Color(0xFFFFD700), const Color(0xFFFF8C00)]
                  : [const Color(0xFF00D4FF), const Color(0xFF7B2FFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: (_isCapturing
                    ? const Color(0xFFFFD700)
                    : const Color(0xFF00D4FF)).withOpacity(0.5),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isCapturing
                    ? Icons.hourglass_top_rounded
                    : Icons.touch_app_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 2),
              Text(
                _isCapturing ? 'Reading…' : 'Hold\nScan',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
