import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toeic_prep/screens/auth/login_screen.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Data setiap halaman on boarding
  static const List<_OnBoardingData> _pages = [
    _OnBoardingData(
      title: 'Selamat Datang di\nTOEIC Prep',
      description:
          'Aplikasi sederhana untuk membantu kamu\nmempersiapkan tes TOEIC kapan saja.',
      imagePath: 'assets/on_boarding/foto_on_boarding1.png',
    ),
    _OnBoardingData(
      title: 'Latihan dan Simulasi',
      description:
          'Kerjakan soal TOEIC dan ikuti simulasi tes\nuntuk meningkatkan kemampuanmu.',
      imagePath: 'assets/on_boarding/foto_on_boarding2.png',
    ),
    _OnBoardingData(
      title: 'Pantau\nPerkembangan',
      description:
          'Lihat skor, review jawaban, dan pantau\npeningkatan kemampuanmu.',
      imagePath: 'assets/on_boarding/foto_on_boarding3.png',
    ),
  ];

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToLogin();
    }
  }

  Future<void> _goToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);

    if (!mounted) return;
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── PageView ─────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnBoardingPage(data: _pages[index]);
                },
              ),
            ),

            // ── Dot Indicator ─────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? const Color(0xFF1E3A8A)
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // ── Tombol bawah ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Row(
                children: [
                  // Tombol Lewati
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _goToLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Lewati',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Tombol Selanjutnya / Daftar
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isLast ? 'Daftar' : 'Selanjutnya',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data model untuk satu halaman on boarding ────────────────────────────────

class _OnBoardingData {
  final String title;
  final String description;
  final String imagePath;

  const _OnBoardingData({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

// ─── Widget satu halaman ──────────────────────────────────────────────────────

class _OnBoardingPage extends StatelessWidget {
  final _OnBoardingData data;

  const _OnBoardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 36),

          // ── Judul ──────────────────────────────────
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 32),

          // ── Gambar ilustrasi ───────────────────────
          Expanded(
            child: Image.asset(
              data.imagePath,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(height: 28),

          // ── Deskripsi ──────────────────────────────
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}