import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/user_session.dart';
import '../../screens/home/beranda.dart';

import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();

  bool _obscurePass = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await UserSession.getSavedCredentials();

    if (!mounted) return;

    if (saved != null) {
      setState(() {
        _emailController.text = saved['email'] ?? '';
        _passController.text = saved['password'] ?? '';
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.login(
        email: _emailController.text.trim(),
        password: _passController.text,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result['status'] == 'success') {
        final user = result['user'];

        // Hapus sesi lama
        await UserSession.clear();

        if (!mounted) return;

        // Simpan sesi user
        await UserSession.save(
          id: int.parse(user['id'].toString()),
          name: user['name'],
          email: user['email'],
          skillLevel: user['skill_level'] ?? 'beginner',
          rememberMe: _rememberMe,
          fotoProfil: user['foto_profil'] ?? '',
        );

        // ======================================================
        // INGAT SAYA
        // ======================================================

        if (_rememberMe) {
          await UserSession.saveCredentials(
            _emailController.text.trim(),
            _passController.text,
          );
        } else {
          await UserSession.clearCredentials();
        }

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => BerandaScreen(
              userId: int.parse(user['id'].toString()),
              userName: user['name'],
              userEmail: user['email'],
              skillLevel: user['skill_level'] ?? 'beginner',
              userPhoto: user['foto_profil'] ?? '',
            ),
          ),
          (_) => false,
        );

        return;
      }

      setState(() {
        _errorMessage = result['message'] ?? 'Email atau password salah';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Tidak dapat terhubung ke server.';
      });
    }
  }

  // ============================================================
  // LUPA PASSWORD
  // ============================================================

  Future<void> _openForgotPassword() async {
    FocusScope.of(context).unfocus();

    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );

    if (!mounted) return;

    // Jika user berhasil reset password,
    // email otomatis dimasukkan ke halaman login.
    if (email != null && email.isNotEmpty) {
      await UserSession.clearCredentials();

      if (!mounted) return;

      setState(() {
        _emailController.text = email;
        _passController.clear();
        _rememberMe = false;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kata sandi berhasil diubah. Silakan masuk menggunakan kata sandi baru.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

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
                // ── Error Banner ─────────────────────────────
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _errorMessage!),
                ],

                const SizedBox(height: 60),

                // ── Logo & Judul ─────────────────────────────
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'TOEIC Prep',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Masuk untuk melanjutkan pembelajaran',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Email ─────────────────────────────────────
                _FieldLabel(text: 'Email'),
                const SizedBox(height: 8),
                _InputField(
                  controller: _emailController,
                  hint: 'contoh@email.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  validator: (v) {
                    final email = v?.trim() ?? '';
                    if (email.isEmpty) return 'Email tidak boleh kosong';
                    if (!email.contains('@') || !email.contains('.')) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ── Kata Sandi ────────────────────────────────
                _FieldLabel(text: 'Kata Sandi'),
                const SizedBox(height: 8),
                _InputField(
                  controller: _passController,
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePass,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_isLoading) _handleLogin();
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Kata sandi tidak boleh kosong'
                      : null,
                ),

                const SizedBox(height: 8),

                // ── Ingat Saya + Lupa Kata Sandi ───────────────
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: const Color(0xFF2563EB),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        onChanged: _isLoading
                            ? null
                            : (value) =>
                                setState(() => _rememberMe = value ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Ingat Saya',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _isLoading ? null : _openForgotPassword,
                      child: const Text(
                        'Lupa Kata Sandi?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Tombol Masuk ───────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF93C5FD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Masuk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Link ke Daftar ─────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                        children: [
                          TextSpan(text: 'Belum Punya Akun? '),
                          TextSpan(
                            text: 'Daftar',
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Widget Reusable
// ════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A1A2E),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final bool enabled;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: Colors.grey[400], size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}