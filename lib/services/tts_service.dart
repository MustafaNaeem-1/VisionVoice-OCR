import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Wraps FlutterTts with smart duplicate-prevention and queue management.
///
/// Only calls [speak] when the incoming text differs from the last spoken
/// text – eliminating TTS stutter on repeated identical frames.
class TtsService {
  TtsService();

  final FlutterTts _tts = FlutterTts();

  String _lastSpokenText = '';
  bool _isSpeaking = false;

  /// Expose the raw [FlutterTts] for direct state queries if needed.
  FlutterTts get engine => _tts;
  bool get isSpeaking => _isSpeaking;

  // ── Initialization ──────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.50); // Slightly slower for accessibility
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Android: prefer on-device engine for offline usage
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _tts.setQueueMode(1); // Flush + speak
    }

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((_) => _isSpeaking = false);
  }

  // ── Smart Speak ─────────────────────────────────────────────────────────────

  /// Speaks [text] only if it differs from the previously spoken text.
  /// Set [force] to true to always speak (e.g., "Hold to Scan" result).
  Future<void> smartSpeak(String text, {bool force = false}) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (!force && trimmed == _lastSpokenText) return; // No change
    _lastSpokenText = trimmed;

    // Strict protection against stuttering
    if (_isSpeaking) return;

    await _tts.setLanguage('en-US');
    await _tts.speak(trimmed);
  }

  /// Speaks [text] immediately, stopping any ongoing speech.
  Future<void> speakNow(String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _lastSpokenText = trimmed;
    await _stopIfSpeaking();
    await _tts.setLanguage('en-US');
    await _tts.speak(trimmed);
  }

  /// Stops any ongoing speech.
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> _stopIfSpeaking() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
      // Brief pause to prevent overlap artifacts
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _tts.stop();
  }
}
