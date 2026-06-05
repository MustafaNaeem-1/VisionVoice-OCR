import 'package:flutter/material.dart';
import '../screens/ocr_scanner_screen.dart';

/// Small animated pill that shows the current [ScanMode].
class ScanModeIndicator extends StatelessWidget {
  const ScanModeIndicator({super.key, required this.mode});

  final ScanMode mode;

  @override
  Widget build(BuildContext context) {
    final bool isLive = mode == ScanMode.live;
    final Color color =
        isLive ? const Color(0xFF00D4FF) : const Color(0xFFFFD700);
    final String label = isLive ? 'LIVE' : 'FROZEN';
    final IconData icon =
        isLive ? Icons.fiber_manual_record : Icons.lock_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
