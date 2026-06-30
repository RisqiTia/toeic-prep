import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toeic_prep/screens/auth/login_screen.dart';
import 'package:toeic_prep/screens/on_boarding_screen.dart';
import 'package:toeic_prep/services/user_session.dart';
import 'package:toeic_prep/screens/home/beranda.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Animasi lingkaran (bubble) muncul dari skala 0 → 1
  late AnimationController _bubbleController;
  late Animation<double> _bubbleScale;
  late Animation<double> _bubbleOpacity;

  // Animasi logo buku muncul di dalam bubble
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // Animasi teks "TOEIC Prep" muncul di bawah logo
  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    // ── Bubble (2.png) ────────────────────────────
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bubbleScale = CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.elasticOut,
    );
    _bubbleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _bubbleController,
        curve: const Interval(0, 0.4),
      ),
    );

    // ── Logo buku (4.png) di dalam bubble ──────
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.5),
      ),
    );

    // ── Teks "TOEIC Prep" (3.png) — di bawah logo ─
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _bubbleController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    _textController.forward();

    // Tahan sebentar sebelum navigasi
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    _navigate();
  }

  Future<void> _navigate() async {
    // Cek apakah sudah pernah melihat onboarding
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

    if (!seenOnboarding) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const OnBoardingScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
      return;
    }

    // Cek sesi login (Ingat Saya aktif)
    final loggedIn = await UserSession.isLoggedIn();
    if (!mounted) return;

    if (loggedIn) {
      final userData = await UserSession.get();
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => BerandaScreen(
            userId: userData?['id'] ?? 0,
            userName: userData?['name'] ?? 'Pengguna',
            userEmail: userData?['email'] ?? '',
            skillLevel: userData?['skill_level'] ?? 'beginner',
            userPhoto: userData?['foto_profil'] ?? '',
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Bubble + Logo buku ──────────────────
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Bubble (2.png) — frame luar
                  FadeTransition(
                    opacity: _bubbleOpacity,
                    child: ScaleTransition(
                      scale: _bubbleScale,
                      child: Image.asset(
                        'assets/logo/2.png',
                        width: 200,
                        height: 200,
                      ),
                    ),
                  ),
                  // Logo buku (4.png) — di dalam bubble
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Image.asset(
                        'assets/logo/4.png',
                        width: 150,
                        height: 150,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Teks "TOEIC Prep" — tepat di bawah logo ─
            FadeTransition(
              opacity: _textOpacity,
              child: SlideTransition(
                position: _textSlide,
                child: Image.asset(
                  'assets/logo/3.png',
                  width: 180,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}