import 'dart:io';
import 'package:flutter/material.dart';
import 'desktop_preview_screen.dart';
import 'permission_screen.dart';

class PlatformLandingScreen extends StatelessWidget {
  const PlatformLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS) {
      return const PermissionScreen();
    }
    return const DesktopPreviewScreen();
  }
}
