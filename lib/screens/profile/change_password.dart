import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class UbahPasswordScreen extends StatefulWidget {
  final int userId;

  const UbahPasswordScreen({super.key, required this.userId});

  @override
  State<UbahPasswordScreen> createState() => _UbahPasswordScreenState();
}

class _UbahPasswordScreenState extends State<UbahPasswordScreen> {
  final _oldPassController     = TextEditingController();
  final _newPassController     = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscureOld     = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;
  String? _errorMessage;

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleSimpan() async {
    setState(() => _errorMessage = null);

    final oldPass     = _oldPassController.text;
    final newPass     = _newPassController.text;
    final confirmPass = _confirmPassController.text;

    // Validasi
    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _errorMessage = 'Semua field harus diisi');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _errorMessage = 'Kata sandi baru minimal 6 karakter');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'Konfirmasi kata sandi tidak cocok');
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.updatePassword(
      userId     : widget.userId,
      oldPassword: oldPass,
      newPassword: newPass,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content         : Text('Kata sandi berhasil diperbarui'),
          backgroundColor : Color(0xFF2563EB),
          behavior        : SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      setState(() => _errorMessage = result['message'] ?? 'Gagal mengubah kata sandi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── AppBar Biru ──────────────────────────────────
          Container(
            width  : double.infinity,
            color  : const Color(0xFF2563EB),
            padding: EdgeInsets.only(
              top   : MediaQuery.of(context).padding.top + 16,
              bottom: 20,
              left  : 16,
              right : 16,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Tombol back kiri
                Align(
                  alignment: Alignment.centerLeft,
                  child    : GestureDetector(
                    onTap : () => Navigator.pop(context),
                    child : const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const Text(
                  'Ubah Kata Sandi',
                  style: TextStyle(
                    fontSize  : 18,
                    fontWeight: FontWeight.w600,
                    color     : Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // ── Error Banner ─────────────────────────
                  if (_errorMessage != null) ...[
                    Container(
                      width  : double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color       : const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _errorMessage!,
                        style    : const TextStyle(color: Colors.white, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Kata Sandi Lama ──────────────────────
                  _FieldLabel(text: 'Kata Sandi Lama'),
                  const SizedBox(height: 8),
                  _PassField(
                    controller : _oldPassController,
                    obscureText: _obscureOld,
                    onToggle   : () => setState(() => _obscureOld = !_obscureOld),
                  ),

                  const SizedBox(height: 16),

                  // ── Kata Sandi Baru ──────────────────────
                  _FieldLabel(text: 'Kata Sandi Baru'),
                  const SizedBox(height: 8),
                  _PassField(
                    controller : _newPassController,
                    obscureText: _obscureNew,
                    onToggle   : () => setState(() => _obscureNew = !_obscureNew),
                  ),

                  const SizedBox(height: 16),

                  // ── Konfirmasi Kata Sandi ────────────────
                  _FieldLabel(text: 'Konfirmasi Kata Sandi'),
                  const SizedBox(height: 8),
                  _PassField(
                    controller : _confirmPassController,
                    obscureText: _obscureConfirm,
                    onToggle   : () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Tombol Simpan (fixed di bawah) ──────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              24, 0, 24,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            child: SizedBox(
              width : double.infinity,
              height: 52,
              child : ElevatedButton(
                onPressed: _isLoading ? null : _handleSimpan,
                style    : ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation      : 0,
                  shape          : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width : 22,
                        height: 22,
                        child : CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Simpan',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget Reusable ───────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize  : 14,
      fontWeight: FontWeight.w500,
      color     : Color(0xFF1A1A2E),
    ),
  );
}

class _PassField extends StatelessWidget {
  final TextEditingController controller;
  final bool                  obscureText;
  final VoidCallback          onToggle;

  const _PassField({
    required this.controller,
    required this.obscureText,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller : controller,
      obscureText: obscureText,
      style      : const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
      decoration : InputDecoration(
        hintText      : '••••••••',
        hintStyle     : const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        prefixIcon    : const Icon(Icons.lock_outline, color: Color(0xFF9CA3AF), size: 20),
        suffixIcon    : GestureDetector(
          onTap : onToggle,
          child : Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: const Color(0xFF9CA3AF),
            size : 20,
          ),
        ),
        filled        : true,
        fillColor     : const Color(0xFFF3F4F6),
        border        : OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide  : BorderSide.none,
        ),
        enabledBorder : OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide  : BorderSide.none,
        ),
        focusedBorder : OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide  : const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}