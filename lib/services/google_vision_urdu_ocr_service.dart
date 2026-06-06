import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String googleVisionApiKey = String.fromEnvironment(
  'GOOGLE_VISION_API_KEY',
);

class GoogleVisionUrduOcrService {
  static const String missingApiKeyMessage =
      'Google Vision API key is missing.';
  static const String missingApiKeyDeveloperMessage =
      'Google Vision API key is missing. Run with --dart-define=GOOGLE_VISION_API_KEY=YOUR_KEY';
  static const String noInternetMessage =
      'Urdu OCR requires internet for accurate recognition.';
  static const String noTextMessage = 'No Urdu text found. Try scanning again.';
  static const Duration requestTimeout = Duration(seconds: 30);

  String lastErrorMessage = '';

  Future<String> recognizeUrduFromImagePath(String imagePath) async {
    lastErrorMessage = '';
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('Urdu online OCR started');
      debugPrint('Urdu online OCR image path: $imagePath');
      debugPrint(
        'Google Vision key present: ${googleVisionApiKey.isNotEmpty}, length: ${googleVisionApiKey.length}',
      );

      if (googleVisionApiKey.isEmpty) {
        lastErrorMessage = missingApiKeyMessage;
        debugPrint(missingApiKeyDeveloperMessage);
        return '';
      }

      if (!await _hasInternetConnection()) {
        lastErrorMessage = noInternetMessage;
        debugPrint('Urdu online OCR error: no internet connection');
        return '';
      }

      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        lastErrorMessage = 'Captured image file is missing.';
        debugPrint('Urdu online OCR error: image file missing');
        return '';
      }

      final imageBytes = await imageFile.readAsBytes();
      debugPrint('Urdu online OCR image size in bytes: ${imageBytes.length}');
      final base64Image = base64Encode(imageBytes);

      final uri = Uri.https('vision.googleapis.com', '/v1/images:annotate', {
        'key': googleVisionApiKey,
      });
      final body = jsonEncode({
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'DOCUMENT_TEXT_DETECTION', 'maxResults': 1},
            ],
            'imageContext': {
              'languageHints': ['ur'],
            },
          },
        ],
      });

      debugPrint('Urdu online OCR request sent');
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(requestTimeout);

      debugPrint('Urdu online OCR HTTP status code: ${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        lastErrorMessage = 'Urdu OCR request failed. Please try again.';
        debugPrint('Urdu online OCR HTTP error: ${response.body}');
        return '';
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        lastErrorMessage = 'Urdu OCR returned an invalid response.';
        debugPrint('Urdu online OCR error: invalid JSON response');
        return '';
      }

      final apiError = _readApiError(decoded);
      if (apiError.isNotEmpty) {
        lastErrorMessage = 'Urdu OCR request failed. Please try again.';
        debugPrint('Urdu online OCR API error: $apiError');
        return '';
      }

      final rawText = _readFullText(decoded);
      debugPrint(
        'Urdu online OCR raw extracted text length: ${rawText.length}',
      );
      final cleaned = _cleanText(rawText);
      if (cleaned.isEmpty) {
        lastErrorMessage = noTextMessage;
      }

      stopwatch.stop();
      debugPrint(
        'Urdu online OCR completed in ${stopwatch.elapsedMilliseconds}ms',
      );
      return cleaned;
    } on TimeoutException {
      stopwatch.stop();
      lastErrorMessage = 'Urdu OCR timed out. Please try again.';
      debugPrint(
        'Urdu online OCR timed out after ${requestTimeout.inSeconds}s',
      );
      return '';
    } on SocketException catch (error) {
      stopwatch.stop();
      lastErrorMessage = noInternetMessage;
      debugPrint('Urdu online OCR network error: $error');
      return '';
    } catch (error, stackTrace) {
      stopwatch.stop();
      lastErrorMessage = 'Urdu OCR failed. Please try again.';
      debugPrint('Urdu online OCR error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return '';
    }
  }

  Future<bool> _hasInternetConnection() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  String _readFullText(Map<String, dynamic> decoded) {
    final responses = decoded['responses'];
    if (responses is! List || responses.isEmpty) return '';

    final first = responses.first;
    if (first is! Map<String, dynamic>) return '';

    final annotation = first['fullTextAnnotation'];
    if (annotation is! Map<String, dynamic>) return '';

    final text = annotation['text'];
    return text is String ? text : '';
  }

  String _readApiError(Map<String, dynamic> decoded) {
    final responses = decoded['responses'];
    if (responses is List && responses.isNotEmpty) {
      final first = responses.first;
      if (first is Map<String, dynamic>) {
        final error = first['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          return message is String ? message : error.toString();
        }
      }
    }

    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      return message is String ? message : error.toString();
    }

    return '';
  }

  String _cleanText(String raw) {
    final normalized =
        raw
            .replaceAll('\uFEFF', '')
            .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E]'), '')
            .split(RegExp(r'\r?\n'))
            .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
            .where((line) => line.isNotEmpty)
            .toList();

    return normalized.join('\n').trim();
  }
}
