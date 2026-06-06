import 'package:flutter/material.dart';
import '../models/recognition_language.dart';

class ScanModeIndicator extends StatelessWidget {
  const ScanModeIndicator({
    super.key,
    required this.status,
    required this.language,
  });

  final ScannerStatus status;
  final RecognitionLanguage language;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ScannerStatus.textDetected => const Color(0xFF55E6A5),
      ScannerStatus.speaking => const Color(0xFF38D7FF),
      ScannerStatus.error => const Color(0xFFFF6B7A),
      _ => const Color(0xFFB7C0D3),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            '${language.shortLabel}  ${status.label}',
            style: const TextStyle(
              color: Color(0xFFF6F9FF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
