import 'package:flutter/material.dart';
import '../models/recognition_language.dart';

class DetectedTextPanel extends StatelessWidget {
  const DetectedTextPanel({
    super.key,
    required this.text,
    required this.status,
    required this.language,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.isSpeaking,
  });

  final String text;
  final ScannerStatus status;
  final RecognitionLanguage language;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    final hasText = text.trim().isNotEmpty;
    final preview =
        hasText ? text.trim() : 'Point the camera at text to begin.';
    final isUrdu = language == RecognitionLanguage.urdu;
    final textDirection =
        isUrdu || _containsArabic(preview)
            ? TextDirection.rtl
            : TextDirection.ltr;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 104,
        maxHeight: MediaQuery.sizeOf(context).height * 0.25,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(16, 21, 34, 0.74),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _StatusDot(status: status, isSpeaking: isSpeaking),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isSpeaking ? ScannerStatus.speaking.label : status.label,
                    style: const TextStyle(
                      color: Color(0xFFF6F9FF),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _LanguageBadge(language: language),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label:
                      isExpanded
                          ? 'Collapse detected text'
                          : 'Expand detected text',
                  child: IconButton(
                    onPressed: onToggleExpanded,
                    icon: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                    ),
                    color: const Color(0xFFF6F9FF),
                    tooltip: isExpanded ? 'Collapse' : 'Expand',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: SelectableText(
                  preview,
                  textDirection: textDirection,
                  textAlign:
                      textDirection == TextDirection.rtl
                          ? TextAlign.right
                          : TextAlign.left,
                  style: TextStyle(
                    color:
                        hasText
                            ? const Color(0xFFF6F9FF)
                            : const Color(0xFFAEB6C6),
                    fontSize: 16,
                    height: 1.38,
                    fontWeight: hasText ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: isExpanded ? null : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _containsArabic(String value) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(value);
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status, required this.isSpeaking});

  final ScannerStatus status;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    final color =
        isSpeaking
            ? const Color(0xFF38D7FF)
            : switch (status) {
              ScannerStatus.textDetected => const Color(0xFF55E6A5),
              ScannerStatus.error => const Color(0xFFFF6B7A),
              ScannerStatus.noText => const Color(0xFFFFC857),
              _ => const Color(0xFF8D96A8),
            };

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 12),
        ],
      ),
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.language});

  final RecognitionLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        language.shortLabel,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          color: Color(0xFFE9F7FF),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
