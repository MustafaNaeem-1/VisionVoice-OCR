import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'ocr_scanner_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  PermissionStatus _cameraStatus = PermissionStatus.denied;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    setState(() => _cameraStatus = status);
    if (status.isGranted) _navigateToScanner();
  }

  Future<void> _requestCamera() async {
    setState(() => _isRequesting = true);
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 45);
    }

    final status = await Permission.camera.request();
    if (!mounted) return;

    setState(() {
      _cameraStatus = status;
      _isRequesting = false;
    });

    if (status.isGranted) {
      _navigateToScanner();
    } else if (status.isPermanentlyDenied) {
      _showSettingsDialog();
    }
  }

  void _navigateToScanner() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                const OCRScannerScreen(),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF141824),
            title: const Text('Camera access is blocked'),
            content: const Text(
              'Open app settings and allow camera access so VisionVoice can scan text on device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final denied = _cameraStatus.isDenied || _cameraStatus.isPermanentlyDenied;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                _buildIcon(),
                const SizedBox(height: 32),
                Text(
                  'Camera access',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'VisionVoice uses the camera to read printed text aloud. Scanning happens on your device, and microphone access is not required.',
                  style: TextStyle(
                    color: Color(0xFFC5CAD8),
                    fontSize: 17,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 28),
                _buildInfoTile(
                  icon: Icons.camera_alt_rounded,
                  title: 'Camera',
                  subtitle:
                      _cameraStatus.isGranted
                          ? 'Allowed'
                          : 'Required for OCR scanning',
                  active: _cameraStatus.isGranted,
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.mic_off_rounded,
                  title: 'Microphone',
                  subtitle: 'Not used. Speech output uses your device speaker.',
                  active: false,
                ),
                if (denied) ...[
                  const SizedBox(height: 18),
                  Text(
                    _cameraStatus.isPermanentlyDenied
                        ? 'Permission is blocked. Use settings to turn it back on.'
                        : 'Camera permission is needed before scanning can start.',
                    style: const TextStyle(
                      color: Color(0xFFFFB4B4),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                FilledButton.icon(
                  onPressed:
                      _isRequesting
                          ? null
                          : (_cameraStatus.isPermanentlyDenied
                              ? _showSettingsDialog
                              : _requestCamera),
                  icon:
                      _isRequesting
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.lock_open_rounded),
                  label: Text(
                    _cameraStatus.isPermanentlyDenied
                        ? 'Open Settings'
                        : 'Allow Camera Access',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF38D7FF), Color(0xFF7A6BFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38D7FF).withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        Icons.visibility_rounded,
        size: 42,
        color: Colors.white,
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool active,
  }) {
    return Semantics(
      label: '$title. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF111622),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFF55E6A5) : const Color(0xFF263044),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFF55E6A5) : const Color(0xFF8D96A8),
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF4F7FB),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFAEB6C6),
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
