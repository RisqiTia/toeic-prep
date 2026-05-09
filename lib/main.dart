import 'package:flutter/material.dart';
import 'services/user_session.dart';
import 'screens/auth/login_screen.dart';
<<<<<<< HEAD
=======
import 'screens/home/beranda.dart';
>>>>>>> 59508cf8d76c3c588521492bf01512ca0ac9ce1a

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOEIC Prep',
<<<<<<< HEAD
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const SplashRouter(),
    );
  }
}

// Cek otomatis apakah user sudah login (Ingat Saya aktif)
class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final loggedIn = await UserSession.isLoggedIn();

    if (!mounted) return;

    if (loggedIn) {
      // User sudah login dan "Ingat Saya" aktif
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (_) => const HomeScreen()),
      // );
      // ── Sementara langsung ke Login dulu ──
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Splash screen sederhana saat cek sesi
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TOEIC Prep',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
              ),
            ),
            SizedBox(height: 12),
            CircularProgressIndicator(
              color: Color(0xFF2563EB),
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
=======
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BerandaScreen(userName: "Jesika Rika"),
>>>>>>> 59508cf8d76c3c588521492bf01512ca0ac9ce1a
    );
  }
}
