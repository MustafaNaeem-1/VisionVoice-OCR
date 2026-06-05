import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Custom [CustomPainter] that draws bounding boxes around each
/// detected [TextBlock] on top of the camera preview.
class TextOverlayPainter extends CustomPainter {
  TextOverlayPainter({
    required this.blocks,
    required this.previewSize,
    this.isFrozen = false,
  });

  final List<TextBlock> blocks;
  final Size previewSize;
  final bool isFrozen;

  @override
  void paint(Canvas canvas, Size size) {
    if (blocks.isEmpty || previewSize == Size.zero) return;

    final Color boxColor =
        isFrozen ? const Color(0xFFFFD700) : const Color(0xFF00D4FF);

    final Paint boxPaint = Paint()
      ..color = boxColor.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint fillPaint = Paint()
      ..color = boxColor.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    // Scale factors: map ML Kit coordinates (in previewSize space) → widget size
    // ML Kit returns coordinates in the camera's coordinate system.
    // The camera is rotated 90° on most Android devices, so width ↔ height swap.
    final double scaleX = size.width / previewSize.height;
    final double scaleY = size.height / previewSize.width;

    for (final TextBlock block in blocks) {
      final Rect boundingBox = block.boundingBox;

      // Transform bounding box to widget coordinates
      final Rect scaledRect = Rect.fromLTRB(
        boundingBox.left * scaleX,
        boundingBox.top * scaleY,
        boundingBox.right * scaleX,
        boundingBox.bottom * scaleY,
      );

      final RRect roundedRect =
          RRect.fromRectAndRadius(scaledRect, const Radius.circular(4));

      canvas.drawRRect(roundedRect, fillPaint);
      canvas.drawRRect(roundedRect, boxPaint);

      // Draw first line of text as label
      if (block.lines.isNotEmpty) {
        final String label = block.lines.first.text;
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: label.length > 30 ? '${label.substring(0, 30)}…' : label,
            style: TextStyle(
              color: boxColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              backgroundColor: Colors.black.withOpacity(0.6),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: scaledRect.width);

        textPainter.paint(
          canvas,
          Offset(scaledRect.left + 4, scaledRect.top + 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(TextOverlayPainter oldDelegate) =>
      oldDelegate.blocks != blocks || oldDelegate.isFrozen != isFrozen;
}
