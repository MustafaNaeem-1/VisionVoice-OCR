enum RecognitionLanguage { english, urdu, auto }

extension RecognitionLanguageDetails on RecognitionLanguage {
  String get label {
    switch (this) {
      case RecognitionLanguage.english:
        return 'English';
      case RecognitionLanguage.urdu:
        return 'Urdu';
      case RecognitionLanguage.auto:
        return 'Auto';
    }
  }

  String get shortLabel {
    switch (this) {
      case RecognitionLanguage.english:
        return 'EN';
      case RecognitionLanguage.urdu:
        return 'UR';
      case RecognitionLanguage.auto:
        return 'AUTO';
    }
  }

  String get ttsLocale {
    switch (this) {
      case RecognitionLanguage.english:
        return 'en-US';
      case RecognitionLanguage.urdu:
        return 'ur-PK';
      case RecognitionLanguage.auto:
        return 'en-US';
    }
  }
}

enum ScannerStatus {
  initializing,
  idle,
  scanning,
  textDetected,
  speaking,
  noText,
  error,
}

extension ScannerStatusDetails on ScannerStatus {
  String get label {
    switch (this) {
      case ScannerStatus.initializing:
        return 'Initializing camera';
      case ScannerStatus.idle:
        return 'Ready to scan';
      case ScannerStatus.scanning:
        return 'Scanning';
      case ScannerStatus.textDetected:
        return 'Text detected';
      case ScannerStatus.speaking:
        return 'Speaking';
      case ScannerStatus.noText:
        return 'No text found';
      case ScannerStatus.error:
        return 'Needs attention';
    }
  }
}
