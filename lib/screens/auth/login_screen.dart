import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/user_session.dart';
import 'register_screen.dart';
import '../../screens/home/beranda.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passController  = TextEditingController();

  bool _obscurePass   = true;
  bool _rememberMe    = false;
  bool _isLoading     = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await ApiService.login(
      email   : _emailController.text.trim(),
      password: _passController.text,
    );

    setState(() => _isLoading = false);

    if (result['status'] == 'success') {
      final user = result['user'];

      // Simpan sesi user
      await UserSession.save(
        id        : user['id'],
        name      : user['name'],
        email     : user['email'],
        skillLevel: user['skill_level'] ?? 'beginner',
        rememberMe: _rememberMe,
      );

      if (!mounted) return;

      // ── Sementara (sebelum Home dibuat): tampilkan snackbar ─
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => BerandaScreen(userName: user['name']),
        ),
        (_) => false,
      );
    } else {
      setState(() => _errorMessage = result['message'] ?? 'Email atau password salah');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Error Banner ──────────────────────────────
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _errorMessage!),
                ],

                const SizedBox(height: 80),

                // ── Logo & Judul ──────────────────────────────
                const Center(
                  child: Column(
                    children: [
                      Text(
                        'TOEIC Prep',
                        style: TextStyle(
                          fontSize  : 28,
                          fontWeight: FontWeight.bold,
                          color     : Color(0xFF1A1A2E),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Persiapan TOEIC Internasional',
                        style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // ── Email ─────────────────────────────────────
                _FieldLabel(text: 'Email'),
                const SizedBox(height: 8),
                TextFormField(
                  controller   : _emailController,
                  keyboardType : TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                  validator: (v) {
                    if (v!.trim().isEmpty) return 'Email tidak boleh kosong';
                    if (!v.contains('@')) return 'Format email tidak valid';
                    return null;
                  },
                  decoration: _inputDecoration(
                    hint      : 'contoh@email.com',
                    prefixIcon: Icons.email_outlined,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Kata Sandi ────────────────────────────────
                _FieldLabel(text: 'Kata Sandi'),
                const SizedBox(height: 8),
                TextFormField(
                  controller : _passController,
                  obscureText: _obscurePass,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                  validator  : (v) => v!.isEmpty ? 'Kata sandi tidak boleh kosong' : null,
                  decoration : _inputDecoration(
                    hint      : '••••••••',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                        size : 20,
                      ),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Ingat Saya ────────────────────────────────
                Row(
                  children: [
                    SizedBox(
                      width : 20,
                      height: 20,
                      child : Checkbox(
                        value          : _rememberMe,
                        onChanged      : (v) => setState(() => _rememberMe = v ?? false),
                        activeColor    : const Color(0xFF2563EB),
                        shape          : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.5),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: const Text(
                        'Ingat Saya',
                        style: TextStyle(
                          fontSize: 14,
                          color   : Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Tombol Masuk ──────────────────────────────
                SizedBox(
                  width : double.infinity,
                  height: 52,
                  child : ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width : 22,
                            height: 22,
                            child : CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Masuk',
                            style: TextStyle(
                              fontSize  : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Link ke Daftar ────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                        children: [
                          TextSpan(text: 'Belum Punya Akun? '),
                          TextSpan(
                            text : 'Daftar',
                            style: TextStyle(
                              color     : Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText   : hint,
      hintStyle  : const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      prefixIcon : Icon(prefixIcon, color: const Color(0xFF9CA3AF), size: 20),
      suffixIcon : suffixIcon,
      filled     : true,
      fillColor  : const Color(0xFFF3F4F6),
      border     : OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide  : BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide  : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide  : const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide  : const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide  : const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

// ── Widget Reusable ──────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize  : 14,
        fontWeight: FontWeight.w500,
        color     : Color(0xFF1A1A2E),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width  : double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color       : const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style    : const TextStyle(color: Colors.white, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}