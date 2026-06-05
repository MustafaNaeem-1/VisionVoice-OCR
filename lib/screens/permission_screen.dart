import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'ocr_scanner_screen.dart';

/// Handles camera + microphone permission requests then
/// routes to [OCRScannerScreen].
class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _micStatus = PermissionStatus.denied;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final camera = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    if (mounted) {
      setState(() {
        _cameraStatus = camera;
        _micStatus = mic;
      });
      if (_cameraStatus.isGranted && _micStatus.isGranted) {
        _navigateToScanner();
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);

    // Haptic feedback
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }

    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cam = statuses[Permission.camera]!;
    final mic = statuses[Permission.microphone]!;

    if (mounted) {
      setState(() {
        _cameraStatus = cam;
        _micStatus = mic;
        _isRequesting = false;
      });

      if (cam.isGranted && mic.isGranted) {
        _navigateToScanner();
      } else if (cam.isPermanentlyDenied || mic.isPermanentlyDenied) {
        _showSettingsDialog();
      }
    }
  }

  void _navigateToScanner() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, b) => const OCRScannerScreen(),
        transitionsBuilder: (_, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Permissions Required',
          style: TextStyle(color: Color(0xFF00D4FF), fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Camera and Microphone permissions are required for VisionVoice to work. '
          'Please enable them in App Settings.',
          style: TextStyle(color: Color(0xFFE8E8F0), fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFAAAAAC))),
          ),
          ElevatedButton(
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
    _pulseController.dispose();
    super.dispose();
  }

  Widget _permissionTile(String label, IconData icon, PermissionStatus status) {
    final bool granted = status.isGranted;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: granted
              ? const Color(0xFF00D4FF).withOpacity(0.5)
              : const Color(0xFF2A2A35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: granted
                  ? const Color(0xFF00D4FF).withOpacity(0.15)
                  : const Color(0xFF2A2A35),
            ),
            child: Icon(
              icon,
              color: granted
                  ? const Color(0xFF00D4FF)
                  : const Color(0xFF666680),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFE8E8F0),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  granted ? 'Granted ✓' : 'Not granted',
                  style: TextStyle(
                    color: granted
                        ? const Color(0xFF00D4FF)
                        : const Color(0xFFAAAAAC),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(),

              // Animated icon
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
                      center: Alignment.topLeft,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D4FF).withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.visibility, size: 56, color: Colors.white),
                ),
              ),

              const SizedBox(height: 36),
              const Text(
                'VisionVoice',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE8E8F0),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Real-time OCR · Text to Speech',
                style: TextStyle(
                  color: Color(0xFF00D4FF),
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Point your camera at any text and let VisionVoice read it aloud for you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFAAAAAC),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 40),

              // Permission tiles
              _permissionTile('Camera Access', Icons.camera_alt_rounded, _cameraStatus),
              _permissionTile('Microphone Access', Icons.mic_rounded, _micStatus),

              const Spacer(),

              // Grant button
              GestureDetector(
                onTap: _isRequesting ? null : _requestPermissions,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D4FF).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isRequesting
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.security_rounded,
                                  color: Colors.white, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                (_cameraStatus.isGranted && _micStatus.isGranted)
                                    ? 'Open Scanner'
                                    : 'Grant Permissions',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Permissions are used only on-device.\nNo data is sent to any server.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFAAAAAC).withOpacity(0.7),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
