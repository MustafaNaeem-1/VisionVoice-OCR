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

  int lastScore = 0;

  Future<String> recognizeUrduFromImagePath(String imagePath) async {
    lastScore = 0;

    try {
      final originalFile = File(imagePath);
      final originalBytes = await originalFile.readAsBytes();
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        debugPrint('Urdu OCR: could not decode image: $imagePath');
        return '';
      }

      final fixedOriginal = img.bakeOrientation(originalImage);
      debugPrint('Urdu OCR original image path: $imagePath');
      debugPrint(
        'Urdu OCR original image size: ${fixedOriginal.width}x${fixedOriginal.height}',
      );
      debugPrint('Urdu OCR original file size: ${await originalFile.length()}');

      final candidates = <_UrduImageCandidate>[
        _UrduImageCandidate(
          label: 'original',
          path: imagePath,
          width: fixedOriginal.width,
          height: fixedOriginal.height,
        ),
        ...await _createProcessedCandidates(fixedOriginal),
      ];

      for (final candidate in candidates.where((c) => c.label != 'original')) {
        debugPrint(
          'Urdu OCR processed image path (${candidate.label}): ${candidate.path}',
        );
        debugPrint(
          'Urdu OCR processed image size (${candidate.label}): ${candidate.width}x${candidate.height}',
        );
      }

      final results = <_UrduOcrResult>[];
      for (final candidate in candidates) {
        final modes =
            candidate.label == 'original' ? const [6] : const [6, 11, 7, 13];

        for (final psm in modes) {
          final raw = await _runTesseract(candidate.path, psm: psm);
          final cleaned = cleanUrduOcrText(raw);
          final score = scoreUrduText(cleaned);

          debugPrint('Urdu OCR ${candidate.label} PSM $psm raw:\n$raw');
          debugPrint('Urdu OCR ${candidate.label} PSM $psm cleaned:\n$cleaned');
          debugPrint('Urdu OCR ${candidate.label} PSM $psm score: $score');

          results.add(
            _UrduOcrResult(
              candidateLabel: candidate.label,
              psm: psm,
              rawText: raw,
              cleanedText: cleaned,
              score: score,
            ),
          );
        }
      }

      if (results.isEmpty) return '';
      results.sort((a, b) => b.score.compareTo(a.score));
      final best = results.first;
      lastScore = best.score;

      debugPrint(
        'Selected Urdu OCR result: ${best.candidateLabel} PSM ${best.psm} score ${best.score}\n${best.cleanedText}',
      );

      return best.cleanedText;
    } catch (error, stackTrace) {
      debugPrint('Urdu OCR failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return '';
    }
  }

  Future<String> preprocessForUrduOcr(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return imagePath;

    final fixed = img.bakeOrientation(decoded);
    final processed = _preprocessImage(_centerCrop(fixed), threshold: 0.56);
    return _writeTempImage(processed, 'urdu_processed_primary');
  }

  Future<List<_UrduImageCandidate>> _createProcessedCandidates(
    img.Image source,
  ) async {
    final crop = _centerCrop(source);
    final soft = _preprocessImage(crop, threshold: null);
    final threshold56 = _preprocessImage(crop, threshold: 0.56);
    final threshold50 = _preprocessImage(crop, threshold: 0.50);

    final processed = <({String label, img.Image image})>[
      (label: 'center-soft', image: soft),
      (label: 'center-threshold-56', image: threshold56),
      (label: 'center-threshold-50', image: threshold50),
    ];

    final candidates = <_UrduImageCandidate>[];
    for (final item in processed) {
      final path = await _writeTempImage(item.image, item.label);
      candidates.add(
        _UrduImageCandidate(
          label: item.label,
          path: path,
          width: item.image.width,
          height: item.image.height,
        ),
      );
    }

    return candidates;
  }

  img.Image _centerCrop(img.Image source) {
    final cropWidth = (source.width * 0.82).round();
    final cropHeight = (source.height * 0.58).round();
    final x = ((source.width - cropWidth) / 2).round();
    final y = ((source.height - cropHeight) / 2).round();

    return img.copyCrop(
      source,
      x: max(0, x),
      y: max(0, y),
      width: min(cropWidth, source.width),
      height: min(cropHeight, source.height),
    );
  }

  img.Image _preprocessImage(img.Image source, {required double? threshold}) {
    var processed = img.Image.from(source);

    processed = img.grayscale(processed);

    if (processed.width < 1500) {
      final scale = processed.width < 900 ? 3 : 2;
      processed = img.copyResize(
        processed,
        width: processed.width * scale,
        interpolation: img.Interpolation.cubic,
      );
    }

    processed = img.adjustColor(processed, contrast: 1.38, brightness: 1.04);
    processed = img.convolution(
      processed,
      filter: const [0, -0.35, 0, -0.35, 2.4, -0.35, 0, -0.35, 0],
      amount: 0.55,
    );

    if (threshold != null) {
      processed = img.luminanceThreshold(processed, threshold: threshold);
    }

    return processed;
  }

  Future<String> _writeTempImage(img.Image image, String label) async {
    final tempDir = await getTemporaryDirectory();
    final safeLabel = label.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final path =
        '${tempDir.path}${Platform.pathSeparator}${safeLabel}_${DateTime.now().microsecondsSinceEpoch}.png';
    await File(path).writeAsBytes(img.encodePng(image), flush: true);
    return path;
  }

  Future<String> _runTesseract(String imagePath, {required int psm}) async {
    return FlutterTesseractOcr.extractText(
      imagePath,
      language: 'urd',
      args: {
        'psm': '$psm',
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
    final digits = RegExp(r'[0-9۰-۹٠-٩]').allMatches(trimmed).length;
    final words = RegExp(r'[\u0600-\u06FF]{2,}').allMatches(trimmed).length;
    final symbols =
        RegExp(
          r'[^\u0600-\u06FF0-9۰-۹٠-٩\s،؛؟۔,.!?()\[\]{}\-:/]',
        ).allMatches(trimmed).length;

    var score = (arabicChars * 3) + (words * 8) + min(digits, 8);
    score -= latinChars * 4;
    score -= symbols * 3;
    if (arabicChars < 4) score -= 30;
    if (trimmed.length < 6) score -= 15;

    return max(0, score).toInt();
  }

  bool containsUrdu(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  String cleanUrduOcrText(String raw) {
    final normalized = raw
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E]'), '')
        .replaceAll(RegExp(r'[A-Za-z]+'), ' ')
        .replaceAll(
          RegExp(r'[^\u0600-\u06FF0-9۰-۹٠-٩\s،؛؟۔,.!?()\[\]{}\-:/]'),
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
}

class _UrduImageCandidate {
  const _UrduImageCandidate({
    required this.label,
    required this.path,
    required this.width,
    required this.height,
  });

  final String label;
  final String path;
  final int width;
  final int height;
}

class _UrduOcrResult {
  const _UrduOcrResult({
    required this.candidateLabel,
    required this.psm,
    required this.rawText,
    required this.cleanedText,
    required this.score,
  });

  final String candidateLabel;
  final int psm;
  final String rawText;
  final String cleanedText;
  final int score;
}
