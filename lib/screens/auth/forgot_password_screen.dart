import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _errorMessage;

  String _resetStatus = 'email';

  // email
  // pending
  // approved
  // completed

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // CEK EMAIL DAN STATUS RESET
  // ============================================================

  Future<void> _checkResetStatus() async {
    if (!_emailFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      final response =
          await ApiService.checkPasswordResetStatus(email: email);

      if (!mounted) return;

      if (response['status'] != 'success') {
        setState(() {
          _isLoading = false;
          _errorMessage =
              response['message'] ?? 'Gagal mengecek status reset kata sandi.';
        });
        return;
      }

      final status = response['reset_status']?.toString() ?? 'none';

      // ========================================================
      // BELUM PERNAH MEMINTA RESET
      // ========================================================

      if (status == 'none' || status == 'completed') {
        await _requestPasswordReset();
        return;
      }

      // ========================================================
      // MASIH MENUNGGU ADMIN
      // ========================================================

      if (status == 'pending') {
        setState(() {
          _isLoading = false;
          _resetStatus = 'pending';
          _errorMessage = null;
        });
        return;
      }

      // ========================================================
      // SUDAH DISETUJUI ADMIN
      // ========================================================

      if (status == 'approved') {
        setState(() {
          _isLoading = false;
          _resetStatus = 'approved';
          _errorMessage = null;
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Status reset kata sandi tidak dikenali.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Terjadi kesalahan saat menghubungi server.';
      });
    }
  }

  // ============================================================
  // KIRIM PERMINTAAN RESET
  // ============================================================

  Future<void> _requestPasswordReset() async {
    final email = _emailController.text.trim();

    try {
      final response = await ApiService.requestPasswordReset(email: email);

      if (!mounted) return;

      if (response['status'] == 'success') {
        final resetStatus = response['reset_status']?.toString();

        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _resetStatus = resetStatus == 'approved' ? 'approved' : 'pending';
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            response['message'] ?? 'Gagal mengirim permintaan reset kata sandi.';
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
  // CEK ULANG STATUS
  // ============================================================

  Future<void> _refreshStatus() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      final response =
          await ApiService.checkPasswordResetStatus(email: email);

      if (!mounted) return;

      if (response['status'] != 'success') {
        setState(() {
          _isLoading = false;
          _errorMessage = response['message'] ?? 'Gagal mengecek status.';
        });
        return;
      }

      final status = response['reset_status']?.toString() ?? 'none';

      if (status == 'approved') {
        setState(() {
          _isLoading = false;
          _resetStatus = 'approved';
        });
        return;
      }

      if (status == 'pending') {
        setState(() {
          _isLoading = false;
          _resetStatus = 'pending';
        });
        return;
      }

      if (status == 'none' || status == 'completed') {
        setState(() {
          _isLoading = false;
          _resetStatus = 'email';
        });
        return;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Tidak dapat terhubung ke server.';
      });
    }
  }

  // ============================================================
  // SIMPAN PASSWORD BARU
  // ============================================================

  Future<void> _saveNewPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final password = _passwordController.text;
    final confirmation = _confirmPasswordController.text;

    if (password != confirmation) {
      setState(() => _errorMessage = 'Konfirmasi kata sandi tidak sama.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.completePasswordReset(
        email: _emailController.text.trim(),
        newPassword: password,
      );

      if (!mounted) return;

      if (response['status'] == 'success') {
        setState(() {
          _isLoading = false;
          _resetStatus = 'completed';
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = response['message'] ?? 'Gagal mengubah kata sandi.';
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Lupa Kata Sandi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildCurrentContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentContent() {
    switch (_resetStatus) {
      case 'pending':
        return _buildPendingContent();
      case 'approved':
        return _buildNewPasswordContent();
      case 'completed':
        return _buildCompletedContent();
      default:
        return _buildEmailContent();
    }
  }

  // ============================================================
  // EMAIL
  // ============================================================

  Widget _buildEmailContent() {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('email'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          _buildHeaderIcon(Icons.lock_reset_rounded),

          const SizedBox(height: 24),

          Center(
            child: Column(
              children: [
                const Text(
                  'Lupa Kata Sandi?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Masukkan email akun TOEIC Prep Anda. Permintaan reset kata sandi akan dikirim kepada admin untuk diverifikasi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          _FieldLabel(text: 'Email'),
          const SizedBox(height: 8),
          _InputField(
            controller: _emailController,
            hint: 'contoh@email.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isLoading) _checkResetStatus();
            },
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Email tidak boleh kosong';
              if (!email.contains('@') || !email.contains('.')) {
                return 'Format email tidak valid';
              }
              return null;
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: _errorMessage!),
          ],

          const SizedBox(height: 24),

          _buildPrimaryButton(
            text: 'Lanjutkan',
            onPressed: _checkResetStatus,
          ),

          const SizedBox(height: 12),

          Center(
            child: TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text(
                'Kembali ke Login',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ============================================================
  // PENDING
  // ============================================================

  Widget _buildPendingContent() {
    return Column(
      key: const ValueKey('pending'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        _buildHeaderIcon(Icons.hourglass_top_rounded),

        const SizedBox(height: 24),

        Center(
          child: Column(
            children: [
              const Text(
                'Menunggu Verifikasi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Permintaan reset kata sandi Anda telah berhasil dikirim dan sedang menunggu verifikasi dari admin.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5, color: Colors.grey[600]),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined, color: Color(0xFF2563EB)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _emailController.text.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(message: _errorMessage!),
        ],

        const SizedBox(height: 24),

        _buildPrimaryButton(
          text: 'Cek Status Verifikasi',
          icon: Icons.refresh_rounded,
          onPressed: _refreshStatus,
        ),

        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text(
              'Kembali ke Login',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ============================================================
  // PASSWORD BARU
  // ============================================================

  Widget _buildNewPasswordContent() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        key: const ValueKey('approved'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          _buildHeaderIcon(Icons.verified_user_outlined),

          const SizedBox(height: 24),

          Center(
            child: Column(
              children: [
                const Text(
                  'Buat Kata Sandi Baru',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Permintaan Anda telah diverifikasi oleh admin. Silakan buat kata sandi baru untuk akun Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          _FieldLabel(text: 'Kata Sandi Baru'),
          const SizedBox(height: 8),
          _InputField(
            controller: _passwordController,
            hint: '••••••••',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            enabled: !_isLoading,
            textInputAction: TextInputAction.next,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Kata sandi tidak boleh kosong';
              }
              if (value.length < 6) return 'Kata sandi minimal 6 karakter';
              return null;
            },
          ),

          const SizedBox(height: 16),

          _FieldLabel(text: 'Konfirmasi Kata Sandi'),
          const SizedBox(height: 8),
          _InputField(
            controller: _confirmPasswordController,
            hint: '••••••••',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
            enabled: !_isLoading,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isLoading) _saveNewPassword();
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey,
              ),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Konfirmasi kata sandi tidak boleh kosong';
              }
              if (value != _passwordController.text) {
                return 'Konfirmasi kata sandi tidak sama';
              }
              return null;
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: _errorMessage!),
          ],

          const SizedBox(height: 24),

          _buildPrimaryButton(
            text: 'Simpan Kata Sandi',
            icon: Icons.save_outlined,
            onPressed: _saveNewPassword,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ============================================================
  // COMPLETED
  // ============================================================

  Widget _buildCompletedContent() {
    return Column(
      key: const ValueKey('completed'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        _buildHeaderIcon(Icons.check_circle_outline_rounded),

        const SizedBox(height: 24),

        Center(
          child: Column(
            children: [
              const Text(
                'Kata Sandi Berhasil Diubah',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kata sandi baru berhasil disimpan. Sekarang Anda dapat masuk menggunakan kata sandi baru.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5, color: Colors.grey[600]),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () =>
                Navigator.pop(context, _emailController.text.trim()),
            icon: const Icon(Icons.login_rounded),
            label: const Text(
              'Kembali ke Login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ============================================================
  // WIDGET HELPER
  // ============================================================

  Widget _buildHeaderIcon(IconData icon) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, size: 38, color: const Color(0xFF2563EB)),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
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
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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