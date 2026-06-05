import 'package:flutter/material.dart';

/// A panel that displays the detected text from the OCR scanner.
/// It features a sleek glassmorphic-inspired dark design with
/// smooth scrolling and high contrast.
class DetectedTextPanel extends StatelessWidget {
  final String text;
  final bool isEmpty;

  const DetectedTextPanel({
    super.key,
    required this.text,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220, // Fixed height for consistent bottom panel
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF333344),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEmpty ? Icons.text_snippet_outlined : Icons.text_snippet_rounded,
                color: isEmpty ? const Color(0xFF666680) : const Color(0xFF00D4FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'DETECTED TEXT',
                style: TextStyle(
                  color: isEmpty ? const Color(0xFF666680) : const Color(0xFF00D4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SelectableText(
                isEmpty ? 'No text detected yet. Point your camera at a document...' : text,
                style: TextStyle(
                  color: isEmpty ? const Color(0xFF888899) : const Color(0xFFF0F0F5),
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: isEmpty ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
