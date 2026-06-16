import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/user_session.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/beranda.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOEIC Prep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        // Terapkan Poppins ke seluruh app sekaligus
        textTheme: GoogleFonts.poppinsTextTheme(),
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
      final userData = await UserSession.get();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BerandaScreen(
            userId    : userData?['id']          ?? 0,
            userName  : userData?['name']         ?? 'Pengguna',
            userEmail : userData?['email']        ?? '',
            skillLevel: userData?['skill_level']  ?? 'beginner',
            userPhoto : userData?['foto_profil']  ?? '', // ← foto profil dari sesi
          ),
        ),
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TOEIC Prep',
              style: GoogleFonts.poppins(
                fontSize  : 32,
                fontWeight: FontWeight.bold,
                color     : const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 12),
            const CircularProgressIndicator(
              color      : Color(0xFF2563EB),
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}