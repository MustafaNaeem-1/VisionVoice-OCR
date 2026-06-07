import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/recognition_language.dart';

typedef OnTtsStateChanged = void Function(bool isSpeaking);

class TtsVoiceUnavailableException implements Exception {
  const TtsVoiceUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TtsService {
  TtsService({this.onStateChanged});

  static const String urduVoiceUnavailableMessage =
      'Urdu voice is not installed on this device. Install an Urdu voice from Android Text-to-Speech settings.';
  static const List<String> _urduLanguageCodes = ['ur-PK', 'ur', 'ur-IN'];
  static const MethodChannel _settingsChannel = MethodChannel(
    'vision_voice/tts_settings',
  );

  final OnTtsStateChanged? onStateChanged;
  final FlutterTts _tts = FlutterTts();

  String _lastSpokenText = '';
  DateTime _lastSpokenAt = DateTime(0);
  RecognitionLanguage _language = RecognitionLanguage.english;
  bool _isSpeaking = false;
  bool _isReady = false;
  Future<void> _speechLock = Future<void>.value();

  static const Duration _minimumGap = Duration(seconds: 4);
  static const double _similarityThreshold = 0.88;

  FlutterTts get engine => _tts;
  bool get isSpeaking => _isSpeaking;
  RecognitionLanguage get language => _language;

  Future<void> initialize() async {
    await _tts.awaitSpeakCompletion(false);
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _tts.setQueueMode(1);
    }

    _tts.setStartHandler(() => _setSpeaking(true));
    _tts.setCompletionHandler(() => _setSpeaking(false));
    _tts.setCancelHandler(() => _setSpeaking(false));
    _tts.setErrorHandler((_) => _setSpeaking(false));

    await setLanguage(RecognitionLanguage.english);
    _isReady = true;
  }

  Future<void> setLanguage(RecognitionLanguage language) async {
    _language = language;
    await _tts.setLanguage(language.ttsLocale);
  }

  Future<bool> isUrduVoiceAvailable() async {
    final selected = await _selectAvailableUrduLanguage();
    final isAvailable = selected != null;
    debugPrint('Urdu TTS voice available: $isAvailable');
    if (selected != null) {
      debugPrint('Selected Urdu TTS language code: $selected');
    }
    return isAvailable;
  }

  Future<void> smartSpeak(
    String text, {
    RecognitionLanguage? language,
    bool force = false,
  }) async {
    final trimmed = _cleanText(text);
    if (!_isReady || trimmed.isEmpty) return;

    final now = DateTime.now();
    if (!force && now.difference(_lastSpokenAt) < _minimumGap) return;
    if (!force && _isSpeaking) return;
    if (!force && _isTooSimilar(trimmed, _lastSpokenText)) return;

    _lastSpokenText = trimmed;
    _lastSpokenAt = now;
    await _runSpeechOperation(
      () => _speak(trimmed, language ?? _language, interrupt: force),
    );
  }

  Future<void> speakNow(String text, {RecognitionLanguage? language}) async {
    final trimmed = _cleanText(text);
    if (!_isReady || trimmed.isEmpty) return;

    _lastSpokenText = trimmed;
    _lastSpokenAt = DateTime.now();
    await _runSpeechOperation(
      () => _speak(trimmed, language ?? _language, interrupt: true),
    );
  }

  Future<void> speakUrdu(String text) async {
    final trimmed = _cleanText(text);
    if (!_isReady || trimmed.isEmpty) return;

    _lastSpokenText = trimmed;
    _lastSpokenAt = DateTime.now();
    await _runSpeechOperation(() async {
      await stop();
      await Future.delayed(const Duration(milliseconds: 120));

      final selectedLanguage = await _selectAvailableUrduLanguage();
      final hasUrduVoice = selectedLanguage != null;
      debugPrint('Urdu TTS voice available: $hasUrduVoice');
      if (!hasUrduVoice) {
        throw const TtsVoiceUnavailableException(urduVoiceUnavailableMessage);
      }

      debugPrint('Selected Urdu TTS language code: $selectedLanguage');
      _language = RecognitionLanguage.urdu;
      await _tts.setLanguage(selectedLanguage);
      await _tts.speak(trimmed);
    });
  }

  Future<void> stop() async {
    await _tts.stop();
    _setSpeaking(false);
  }

  Future<void> dispose() async {
    await stop();
  }

  Future<void> openTtsSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _settingsChannel.invokeMethod<void>('openTtsSettings');
  }

  Future<void> _speak(
    String text,
    RecognitionLanguage language, {
    required bool interrupt,
  }) async {
    if (interrupt && _isSpeaking) {
      await _tts.stop();
      _setSpeaking(false);
      await Future.delayed(const Duration(milliseconds: 120));
    }

    await setLanguage(
      language == RecognitionLanguage.auto ? _languageForText(text) : language,
    );
    await _tts.speak(text);
  }

  Future<void> _runSpeechOperation(Future<void> Function() operation) {
    final previous = _speechLock;
    final completer = Completer<void>();
    _speechLock = completer.future;

    return previous.catchError((_) {}).then((_) async {
      try {
        await operation();
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(error, stackTrace);
      } finally {
        completer.complete();
      }
    });
  }

  Future<String?> _selectAvailableUrduLanguage() async {
    final availableLanguages = await _availableLanguageCodes();
    debugPrint('Available TTS languages: $availableLanguages');

    for (final code in _urduLanguageCodes) {
      if (await _isLanguageAvailable(code, availableLanguages)) {
        return code;
      }
    }
    return null;
  }

  Future<Set<String>> _availableLanguageCodes() async {
    try {
      final dynamic languages = await _tts.getLanguages;
      if (languages is! Iterable) return <String>{};
      return languages
          .map((language) => language.toString())
          .where((language) => language.trim().isNotEmpty)
          .toSet();
    } catch (error) {
      debugPrint('Unable to read available TTS languages: $error');
      return <String>{};
    }
  }

  Future<bool> _isLanguageAvailable(
    String code,
    Set<String> availableLanguages,
  ) async {
    final normalizedCode = _normalizeLanguageCode(code);
    final isListed = availableLanguages.any(
      (language) => _normalizeLanguageCode(language) == normalizedCode,
    );
    if (isListed) return true;

    try {
      final dynamic result = await _tts.isLanguageAvailable(code);
      return result == true || result == 1 || result == '1';
    } catch (error) {
      debugPrint('Unable to check TTS language $code: $error');
      return false;
    }
  }

  String _normalizeLanguageCode(String code) {
    return code.replaceAll('_', '-').toLowerCase();
  }

  RecognitionLanguage _languageForText(String text) {
    final hasArabicScript = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
    return hasArabicScript
        ? RecognitionLanguage.urdu
        : RecognitionLanguage.english;
  }

  bool _isTooSimilar(String next, String previous) {
    if (previous.isEmpty) return false;
    if (next == previous) return true;

    final a = next.toLowerCase();
    final b = previous.toLowerCase();
    final distance = _levenshtein(a, b);
    final longest = max(a.length, b.length);
    if (longest == 0) return true;
    final similarity = 1 - (distance / longest);
    return similarity >= _similarityThreshold;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> previous = List<int>.generate(b.length + 1, (i) => i);
    for (int i = 0; i < a.length; i++) {
      final current = <int>[i + 1];
      for (int j = 0; j < b.length; j++) {
        final insert = current[j] + 1;
        final delete = previous[j + 1] + 1;
        final replace =
            previous[j] + (a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1);
        current.add(min(min(insert, delete), replace));
      }
      previous = current;
    }
    return previous.last;
  }

  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _setSpeaking(bool value) {
    if (_isSpeaking == value) return;
    _isSpeaking = value;
    onStateChanged?.call(value);
  }
}
