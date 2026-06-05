import 'package:flutter/material.dart';
import 'permission_screen.dart';

/// Animated splash screen that transitions to [PermissionScreen] after 2.5 s.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _logoScale = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5)),
    );
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _runAnimations();
  }

  Future<void> _runAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, a, b) => const PermissionScreen(),
          transitionsBuilder: (_, a, b, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A0F), Color(0xFF0D0D1A), Color(0xFF0A0A0F)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              AnimatedBuilder(
                animation: _logoController,
                builder: (_, child) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: child,
                  ),
                ),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D4FF).withOpacity(0.45),
                        blurRadius: 50,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: const Color(0xFF7B2FFF).withOpacity(0.3),
                        blurRadius: 60,
                        spreadRadius: 5,
                        offset: const Offset(20, 20),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.visibility_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Text block
              AnimatedBuilder(
                animation: _textController,
                builder: (_, child) => Opacity(
                  opacity: _textOpacity.value,
                  child: SlideTransition(position: _textSlide, child: child),
                ),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
                      ).createShader(bounds),
                      child: const Text(
                        'VisionVoice',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'See the World Through Sound',
                      style: TextStyle(
                        color: Color(0xFFAAAAAC),
                        fontSize: 15,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF00D4FF)),
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
