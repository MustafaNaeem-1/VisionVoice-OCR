import 'package:flutter/material.dart';

class DesktopPreviewScreen extends StatelessWidget {
  const DesktopPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080A12), Color(0xFF0E1528), Color(0xFF080A12)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 28),
                    _buildPreviewPanel(),
                    const SizedBox(height: 24),
                    _buildStatusStrip(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF38D7FF), Color(0xFF7A6BFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38D7FF).withValues(alpha: 0.20),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: const Icon(
            Icons.visibility_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VisionVoice',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'See the World Through Sound',
                style: TextStyle(
                  color: Color(0xFFB7C0D3),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF101522).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.desktop_windows_rounded,
                color: Color(0xFF38D7FF),
                size: 26,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Desktop and web preview',
                  style: TextStyle(
                    color: Color(0xFFF6F9FF),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'This build target lets you open and review the redesigned VisionVoice app shell on Windows or in a browser. Live camera OCR and ML Kit text recognition remain available on Android and iOS, where Google ML Kit provides the native scanner pipeline used by this app.',
            style: TextStyle(
              color: Color(0xFFD4DCEC),
              fontSize: 16,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _CapabilityChip(
                icon: Icons.check_rounded,
                label: 'Runs on Windows',
              ),
              _CapabilityChip(icon: Icons.check_rounded, label: 'Runs on web'),
              _CapabilityChip(
                icon: Icons.phone_android_rounded,
                label: 'OCR on mobile',
              ),
              _CapabilityChip(
                icon: Icons.volume_up_rounded,
                label: 'TTS on mobile',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFFFC857)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Connect an Android/iOS device later to use real-time OCR. For now, use this platform build to verify navigation, branding, and theme.',
              style: TextStyle(
                color: Color(0xFFD4DCEC),
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF55E6A5), size: 18),
          const SizedBox(width: 8),
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
    );
  }
}
