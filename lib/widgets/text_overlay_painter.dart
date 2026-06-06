import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
        isFrozen ? const Color(0xFFFFC857) : const Color(0xFF38D7FF);
    final Paint boxPaint =
        Paint()
          ..color = boxColor.withValues(alpha: 0.70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
    final Paint fillPaint =
        Paint()
          ..color = boxColor.withValues(alpha: 0.04)
          ..style = PaintingStyle.fill;

    final double scaleX = size.width / previewSize.height;
    final double scaleY = size.height / previewSize.width;

    for (final TextBlock block in blocks.take(18)) {
      final Rect boundingBox = block.boundingBox;
      final Rect scaledRect = Rect.fromLTRB(
        boundingBox.left * scaleX,
        boundingBox.top * scaleY,
        boundingBox.right * scaleX,
        boundingBox.bottom * scaleY,
      );
      final RRect roundedRect = RRect.fromRectAndRadius(
        scaledRect,
        const Radius.circular(5),
      );

      canvas.drawRRect(roundedRect, fillPaint);
      canvas.drawRRect(roundedRect, boxPaint);
    }
  }

  @override
  bool shouldRepaint(TextOverlayPainter oldDelegate) {
    return oldDelegate.blocks != blocks || oldDelegate.isFrozen != isFrozen;
  }
}
