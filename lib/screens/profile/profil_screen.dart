import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/user_session.dart';
import '../auth/login_screen.dart';
import 'change_password.dart';

class ProfilScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String skillLevel;
  final int userId;

  const ProfilScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.skillLevel,
    required this.userId,
  });

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  late TextEditingController _nameController;
  bool _isEditingName = false;
  bool _isSavingName  = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Konversi nilai skill_level dari DB ke label bahasa Indonesia
  String _skillLabel(String level) {
    switch (level) {
      case 'beginner':     return 'Pemula';
      case 'intermediate': return 'Menengah';
      case 'advanced':     return 'Mahir';
      default:             return level;
    }
  }

  // Simpan nama baru ke API
  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content         : Text('Nama tidak boleh kosong'),
          backgroundColor : Colors.red,
          behavior        : SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSavingName = true);

    final result = await ApiService.updateName(
      userId : widget.userId,
      newName: newName,
    );

    setState(() {
      _isSavingName   = false;
      _isEditingName  = false;
    });

    if (!mounted) return;

    if (result['status'] == 'success') {
      // Update nama di sesi lokal
      final session = await UserSession.get();
      if (session != null) {
        await UserSession.save(
          id        : session['id'],
          name      : newName,
          email     : session['email'],
          skillLevel: session['skill_level'],
          rememberMe: session['remember_me'],
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content         : Text('Nama berhasil diperbarui'),
          backgroundColor : Color(0xFF2563EB),
          behavior        : SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content         : Text(result['message'] ?? 'Gagal memperbarui nama'),
          backgroundColor : Colors.red,
          behavior        : SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Dialog konfirmasi logout
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape           : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title           : const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
        content         : const Text('Apakah kamu yakin ingin keluar dari akun ini?'),
        actions         : [
          TextButton(
            onPressed : () => Navigator.pop(context),
            child     : const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed : () async {
              await UserSession.clear();
              //await UserSession.clearCredentials();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            child: const Text(
              'Keluar',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── AppBar Biru ──────────────────────────────────
          Container(
            width : double.infinity,
            color : const Color(0xFF2563EB),
            padding: EdgeInsets.only(
              top   : MediaQuery.of(context).padding.top + 16,
              bottom: 20,
            ),
            child: const Text(
              'Profil',
              textAlign : TextAlign.center,
              style     : TextStyle(
                fontSize  : 18,
                fontWeight: FontWeight.w600,
                color     : Colors.white,
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),

                  // ── Foto Profil ──────────────────────────
                  Center(
                    child: Container(
                      width      : 80,
                      height     : 80,
                      decoration : BoxDecoration(
                        shape : BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2563EB), width: 2.5),
                        color : const Color(0xFFF3F4F6),
                      ),
                      child: const CircleAvatar(
                        backgroundColor: Color(0xFFF3F4F6),
                        child: Icon(
                          Icons.person,
                          size : 44,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Nama Pengguna ────────────────────────
                  _FieldLabel(text: 'Nama Pengguna'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color       : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border      : _isEditingName
                          ? Border.all(color: const Color(0xFF2563EB), width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 14),
                          child  : Icon(Icons.person_outline, color: Color(0xFF9CA3AF), size: 20),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            enabled   : _isEditingName,
                            style     : const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                            decoration: const InputDecoration(
                              border         : InputBorder.none,
                              contentPadding : EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                          ),
                        ),
                        // Tombol edit / simpan
                        _isSavingName
                            ? const Padding(
                                padding: EdgeInsets.only(right: 14),
                                child  : SizedBox(
                                  width : 18,
                                  height: 18,
                                  child : CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : GestureDetector(
                                onTap: () {
                                  if (_isEditingName) {
                                    _saveName();
                                  } else {
                                    setState(() => _isEditingName = true);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child  : Icon(
                                    _isEditingName ? Icons.check : Icons.edit,
                                    color: _isEditingName
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF9CA3AF),
                                    size : 20,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Email (read only) ────────────────────
                  _FieldLabel(text: 'Email'),
                  const SizedBox(height: 8),
                  _ReadOnlyField(
                    icon : Icons.email_outlined,
                    value: widget.userEmail,
                  ),

                  const SizedBox(height: 16),

                  // ── Level (read only) ────────────────────
                  _FieldLabel(text: 'Level'),
                  const SizedBox(height: 8),
                  _ReadOnlyField(
                    icon : Icons.trending_up_rounded,
                    value: _skillLabel(widget.skillLevel),
                  ),

                  const SizedBox(height: 32),

                  // ── Tombol Ubah Password ─────────────────
                  SizedBox(
                    width : double.infinity,
                    height: 52,
                    child : OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UbahPasswordScreen(userId: widget.userId),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side           : const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        shape          : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Ubah Password',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Tombol Keluar ────────────────────────
                  SizedBox(
                    width : double.infinity,
                    height: 52,
                    child : ElevatedButton(
                      onPressed: _confirmLogout,
                      style    : ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation      : 0,
                        shape          : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Keluar',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
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

class _ReadOnlyField extends StatelessWidget {
  final IconData icon;
  final String   value;
  const _ReadOnlyField({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding   : const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color       : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
          ),
        ],
      ),
    );
  }
}