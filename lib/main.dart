import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait-only for stable OCR framing
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF080A12),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const VisionVoiceApp());
}

class VisionVoiceApp extends StatelessWidget {
  const VisionVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VisionVoice',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: _buildDarkTheme(),
      theme: _buildDarkTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildDarkTheme() {
    const Color primary = Color(0xFF38D7FF);
    const Color accent = Color(0xFF7A6BFF);
    const Color background = Color(0xFF080A12);
    const Color surface = Color(0xFF111622);
    const Color onSurface = Color(0xFFF4F7FB);

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        onSurface: onSurface,
        error: Color(0xFFFF6B7A),
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primary, size: 28),
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          minimumSize: const Size(200, 60),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          minimumSize: const Size(64, 56),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: onSurface,
          fontSize: 34,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: TextStyle(
          color: onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: onSurface, fontSize: 18, height: 1.6),
        bodyMedium: TextStyle(
          color: Color(0xFFB7C0D3),
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }
}
