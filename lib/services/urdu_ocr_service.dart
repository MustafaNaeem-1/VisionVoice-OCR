import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class UrduOcrService {
  static const String lowConfidenceMessage =
      'Urdu text detected but confidence is low. Try moving closer, improving lighting, and keeping the text straight.';
  static const int lowConfidenceScoreThreshold = 28;
  static const Duration ocrTimeout = Duration(seconds: 20);

  int lastScore = 0;

  Future<String> recognizeUrduFromImagePath(String imagePath) async {
    lastScore = 0;
    final stopwatch = Stopwatch()..start();
    String? processedPath;

    try {
      debugPrint('Urdu OCR scan started');
      debugPrint('Urdu OCR captured image path: $imagePath');

      final tempDir = await getTemporaryDirectory();
      final processed = await compute(
        _preprocessUrduImage,
        _UrduPreprocessRequest(imagePath, tempDir.path),
      );
      processedPath = processed.path;

      debugPrint(
        'Urdu OCR original size: ${processed.originalWidth}x${processed.originalHeight}',
      );
      debugPrint(
        'Urdu OCR processed size: ${processed.processedWidth}x${processed.processedHeight}',
      );
      debugPrint('Urdu OCR processed image path: $processedPath');
      debugPrint('Urdu OCR started');

      final raw = await _runTesseract(processedPath).timeout(
        ocrTimeout,
        onTimeout: () {
          debugPrint('Urdu OCR timed out after ${ocrTimeout.inSeconds}s');
          return '';
        },
      );

      final cleaned = cleanUrduOcrText(raw);
      lastScore = scoreUrduText(cleaned);

      stopwatch.stop();
      debugPrint('Urdu OCR raw:\n$raw');
      debugPrint('Urdu OCR cleaned:\n$cleaned');
      debugPrint('Urdu OCR score: $lastScore');
      debugPrint('Urdu OCR finished in ${stopwatch.elapsedMilliseconds}ms');

      return cleaned;
    } catch (error, stackTrace) {
      stopwatch.stop();
      debugPrint(
        'Urdu OCR error after ${stopwatch.elapsedMilliseconds}ms: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return '';
    } finally {
      if (processedPath != null) {
        await _deleteIfPresent(processedPath);
      }
    }
  }

  Future<String> preprocessForUrduOcr(String imagePath) async {
    final tempDir = await getTemporaryDirectory();
    final processed = await compute(
      _preprocessUrduImage,
      _UrduPreprocessRequest(imagePath, tempDir.path),
    );
    return processed.path;
  }

  Future<String> _runTesseract(String imagePath) async {
    return FlutterTesseractOcr.extractText(
      imagePath,
      language: 'urd',
      args: const {
        'psm': '6',
        'preserve_interword_spaces': '1',
        'tessedit_do_invert': '0',
        'user_defined_dpi': '300',
      },
    );
  }

  int scoreUrduText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;

    final arabicChars = RegExp(r'[\u0600-\u06FF]').allMatches(trimmed).length;
    final latinChars = RegExp(r'[A-Za-z]').allMatches(trimmed).length;
    final digits =
        RegExp(r'[0-9\u06F0-\u06F9\u0660-\u0669]').allMatches(trimmed).length;
    final words = RegExp(r'[\u0600-\u06FF]{2,}').allMatches(trimmed).length;
    final symbols =
        RegExp(
          r'[^\u0600-\u06FF0-9\u06F0-\u06F9\u0660-\u0669\s،؛؟۔,.!?()\[\]{}\-:/]',
        ).allMatches(trimmed).length;

    var score = (arabicChars * 3) + (words * 8) + min(digits, 8);
    score -= latinChars * 4;
    score -= symbols * 3;
    if (arabicChars < 4) score -= 30;
    if (trimmed.length < 6) score -= 15;

    return max(0, score).toInt();
  }

  String cleanUrduOcrText(String raw) {
    final normalized = raw
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E]'), '')
        .replaceAll(RegExp(r'[A-Za-z]+'), ' ')
        .replaceAll(
          RegExp(
            r'[^\u0600-\u06FF0-9\u06F0-\u06F9\u0660-\u0669\s،؛؟۔,.!?()\[\]{}\-:/]',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'([،؛؟۔,.!?])\1{2,}'), r'$1')
        .replaceAll(RegExp(r'[ \t]+'), ' ');

    final lines =
        normalized
            .split(RegExp(r'\r?\n'))
            .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
            .where((line) => line.isNotEmpty)
            .toList();

    return lines.join('\n').trim();
  }

  Future<void> _deleteIfPresent(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

class _UrduPreprocessRequest {
  const _UrduPreprocessRequest(this.imagePath, this.tempDirectoryPath);

  final String imagePath;
  final String tempDirectoryPath;
}

class _UrduPreprocessResult {
  const _UrduPreprocessResult({
    required this.path,
    required this.originalWidth,
    required this.originalHeight,
    required this.processedWidth,
    required this.processedHeight,
  });

  final String path;
  final int originalWidth;
  final int originalHeight;
  final int processedWidth;
  final int processedHeight;
}

Future<_UrduPreprocessResult> _preprocessUrduImage(
  _UrduPreprocessRequest request,
) async {
  final bytes = await File(request.imagePath).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Could not decode captured image.');
  }

  final fixed = img.bakeOrientation(decoded);
  var processed = img.grayscale(fixed);

  if (processed.width > 1600) {
    processed = img.copyResize(
      processed,
      width: 1600,
      interpolation: img.Interpolation.linear,
    );
  } else if (processed.width < 900) {
    processed = img.copyResize(
      processed,
      width: 1200,
      interpolation: img.Interpolation.linear,
    );
  }

  processed = img.adjustColor(processed, contrast: 1.16, brightness: 1.02);
  processed = img.luminanceThreshold(processed, threshold: 0.55);

  final outputPath =
      '${request.tempDirectoryPath}${Platform.pathSeparator}urdu_ocr_${DateTime.now().microsecondsSinceEpoch}.png';
  await File(outputPath).writeAsBytes(img.encodePng(processed), flush: true);

  return _UrduPreprocessResult(
    path: outputPath,
    originalWidth: fixed.width,
    originalHeight: fixed.height,
    processedWidth: processed.width,
    processedHeight: processed.height,
  );
}
