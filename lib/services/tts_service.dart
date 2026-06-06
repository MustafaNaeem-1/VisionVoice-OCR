import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/recognition_language.dart';

typedef OnTtsStateChanged = void Function(bool isSpeaking);

class TtsService {
  TtsService({this.onStateChanged});

  final OnTtsStateChanged? onStateChanged;
  final FlutterTts _tts = FlutterTts();

  String _lastSpokenText = '';
  DateTime _lastSpokenAt = DateTime(0);
  RecognitionLanguage _language = RecognitionLanguage.english;
  bool _isSpeaking = false;
  bool _isReady = false;

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
    await _speak(trimmed, language ?? _language, interrupt: force);
  }

  Future<void> speakNow(String text, {RecognitionLanguage? language}) async {
    final trimmed = _cleanText(text);
    if (!_isReady || trimmed.isEmpty) return;

    _lastSpokenText = trimmed;
    _lastSpokenAt = DateTime.now();
    await _speak(trimmed, language ?? _language, interrupt: true);
  }

  Future<void> stop() async {
    await _tts.stop();
    _setSpeaking(false);
  }

  Future<void> dispose() async {
    await stop();
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
