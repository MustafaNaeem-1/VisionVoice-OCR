================================================================================
 VISIONVOICE: REAL-TIME ACCESSIBILITY OCR & SPEECH SYSTEM
================================================================================

1. PROJECT OVERVIEW
-------------------
VisionVoice is a cutting-edge accessibility application designed to empower 
individuals with visual impairments and low vision. The application acts as a 
"digital eye," utilizing on-device Machine Learning to convert the physical 
world into spoken word in real-time. Built using the Flutter framework, it 
prioritizes privacy, speed, and reliability by performing all processing 
locally without the need for an internet connection.

2. PROBLEM STATEMENT
--------------------
Visually impaired individuals face significant challenges in:
- Reading printed documents (bills, prescriptions, letters).
- Identifying signage in public spaces.
- Navigating menus and product labels.
Most existing solutions are either expensive specialized hardware or slow 
cloud-based apps that fail in areas with poor connectivity. VisionVoice 
bridges this gap with a high-performance, low-cost mobile solution.

3. CORE TECHNOLOGIES & STACK
----------------------------
- Framework: Flutter (Google's cross-platform UI toolkit).
- Language: Dart.
- Machine Learning: Google ML Kit (Text Recognition v2).
- Hardware Integration: CameraX API for high-frequency frame streaming.
- Audio Engine: Flutter Text-to-Speech (TTS).
- Performance: NV21 Image Format processing for low-latency OCR.

4. SYSTEM ARCHITECTURE
----------------------
The project follows a modular, Service-Oriented Architecture (SOA):
- UI Layer: Material 3 dark-themed screens optimized for high contrast.
- Camera Service: Manages the lifecycle of the camera and raw frame streaming.
- ML Pipeline: Converts camera frames into InputImages, processes them through 
  ML Kit, and extracts localized text blocks.
- Speech Service: Orchestrates the TTS queue, implementing "Smart Speak" logic 
  to prevent overlapping audio.

5. KEY FEATURES
---------------
- Real-Time OCR: Processes camera feed at high frame rates for instant feedback.
- Hold to Scan (Deep Scan): Freezes the feed to capture high-resolution images 
  for complex documents, reading the entire content sequentially.
- Smart Speak Logic: 
  * Duplicate Suppression: Intelligently filters out repeated words.
  * Speech Guard: Ensures only one sentence is read at a time to maintain clarity.
- Haptic Feedback: Uses vibration patterns to signal successful scans, mode 
  switches, and error states, providing non-visual cues.

6. HCI (HUMAN-COMPUTER INTERACTION) PRINCIPLES
----------------------------------------------
VisionVoice is built on core HCI foundations for accessibility:
- Visibility: High-contrast colors (Cyan on Black) reduce eye strain for 
  low-vision users.
- Feedback: Every action (tap, scan, error) is confirmed via both audio and 
  vibration (Haptics).
- Constraints: The UI is simplified with large, easy-to-hit buttons to prevent 
  accidental triggers.
- Forgiveness: Error handling for camera permissions and sensor availability 
  ensures the user is never stuck in a broken state.

7. TECHNICAL OPTIMIZATIONS
--------------------------
- Hardware Compatibility: Specially tuned for mid-range devices (e.g., Samsung 
  A31) by optimizing frame resolution to 480p, reducing CPU load while 
  maintaining OCR accuracy.
- Multi-threaded Processing: ML processing is decoupled from the UI thread to 
  ensure the camera preview remains smooth (60fps).
- State Management: Uses reactive programming to update detected text panels 
  instantly as the user moves the camera.

8. INSTALLATION & SETUP
-----------------------
1. Install Flutter SDK (3.7.0 or higher).
2. Connect an Android/iOS device (Physical device recommended for camera).
3. Run 'flutter pub get' to install dependencies.
4. Run 'flutter run --release' for optimal performance.

9. PROJECT STRUCTURE
--------------------
lib/
├── main.dart            - Entry point & Global Theme configuration.
├── screens/
│   ├── splash_screen.dart       - Interactive loading & branding.
│   ├── permission_screen.dart   - Dynamic permission handling.
│   └── ocr_scanner_screen.dart  - Core logic and camera interface.
├── services/
│   ├── camera_service.dart      - ML Kit and Camera integration.
│   └── tts_service.dart         - Text-to-Speech orchestration.
└── utils/
    └── image_utils.dart         - Format conversion & rotation logic.

10. FUTURE SCOPE
----------------
- Multilingual Support: Recognition of 50+ languages.
- Object Detection: Identifying common objects (chairs, doors, bottles).
- Currency Recognition: Helping users identify banknotes.
- Cloud Sync (Optional): Saving scanned documents to a secure vault.

11. CONCLUSION
--------------
VisionVoice represents a significant step forward in mobile assistive 
technology. By combining real-time machine learning with user-centric design, 
it provides a vital tool for independence for the visually impaired community.

--------------------------------------------------------------------------------
Developed for: HCI Final Project / Final Year Project
Version: 1.0.0
--------------------------------------------------------------------------------
