import 'package:flutter/foundation.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

class UrduOcrService {
  Future<String> recognizeUrduFromImagePath(String imagePath) async {
    try {
      final text = await TesseractOcr.extractText(
        imagePath,
        config: const OCRConfig(language: 'urd', engine: OCREngine.tesseract),
      );

      return _cleanText(text);
    } catch (error, stackTrace) {
      debugPrint('Urdu OCR failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return '';
    }
  }

  String _cleanText(String text) {
    final normalizedLines =
        text
            .replaceAll('\uFEFF', '')
            .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E]'), '')
            .split(RegExp(r'\r?\n'))
            .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
            .where((line) => line.isNotEmpty)
            .toList();

    return normalizedLines.join('\n').trim();
  }
}
