import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/user_session.dart';
import '../auth/login_screen.dart';
import 'change_password.dart';

class ProfilScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String skillLevel;
  final int userId;
  final String userPhoto;
  final void Function(String newName)? onNameUpdated;
  final void Function(String newPhoto)? onPhotoUpdated;

  const ProfilScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.skillLevel,
    required this.userId,
    this.userPhoto = '',
    this.onNameUpdated,
    this.onPhotoUpdated,
  });

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  late TextEditingController _nameController;
  bool _isEditingName = false;
  bool _isSavingName = false;
  bool _isUploadingPhoto = false;

  late String _currentPhoto;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _currentPhoto = widget.userPhoto;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Notifikasi dari Atas (Overlay) ───────────────────────────

  void _showTopNotif(String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _TopNotifWidget(
        message: message,
        isError: isError,
        onDone: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  // ── Helpers ──────────────────────────────────────────────────

  String _skillLabel(String level) {
    switch (level) {
      case 'beginner':
        return 'Pemula';
      case 'intermediate':
        return 'Menengah';
      case 'advanced':
        return 'Mahir';
      default:
        return level;
    }
  }

  String get _photoUrl {
    if (_currentPhoto.isEmpty) return '';
    return '${ApiService.mediaBaseUrl}/uploads/profil/$_currentPhoto';
  }

  // ── Simpan Nama ───────────────────────────────────────────────

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      _showTopNotif('Nama tidak boleh kosong', isError: true);
      return;
    }

    setState(() => _isSavingName = true);

    final result = await ApiService.updateName(
      userId: widget.userId,
      newName: newName,
    );

    setState(() {
      _isSavingName = false;
      _isEditingName = false;
    });

    if (!mounted) return;

    if (result['status'] == 'success') {
      final session = await UserSession.get();
      if (session != null) {
        await UserSession.save(
          id: session['id'],
          name: newName,
          email: session['email'],
          skillLevel: session['skill_level'],
          rememberMe: session['remember_me'],
          fotoProfil: session['foto_profil'],
        );
      }
      widget.onNameUpdated?.call(newName);
      _showTopNotif('Nama berhasil diperbarui');
    } else {
      _showTopNotif(
        result['message'] ?? 'Gagal memperbarui nama',
        isError: true,
      );
    }
  }

  // ── Pilih & Upload Foto ───────────────────────────────────────

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Ganti Foto Profil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFF2563EB),
                ),
                title: const Text('Ambil Foto dari Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUpload(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF2563EB),
                ),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUpload(ImageSource.gallery);
                },
              ),
              if (_currentPhoto.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Hapus Foto',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmHapusFoto();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);

    final result = await ApiService.updateProfilePhoto(
      userId: widget.userId,
      imageFile: File(picked.path),
    );

    setState(() => _isUploadingPhoto = false);

    if (!mounted) return;

    if (result['status'] == 'success') {
      final namaFile = result['foto_profil'] as String;
      setState(() => _currentPhoto = namaFile);

      final session = await UserSession.get();
      if (session != null) {
        await UserSession.save(
          id: session['id'],
          name: session['name'],
          email: session['email'],
          skillLevel: session['skill_level'],
          rememberMe: session['remember_me'],
          fotoProfil: namaFile,
        );
      }

      widget.onPhotoUpdated?.call(namaFile);
      _showTopNotif('Foto profil berhasil diperbarui');
    } else {
      _showTopNotif(
        result['message'] ?? 'Gagal mengunggah foto',
        isError: true,
      );
    }
  }

  void _confirmHapusFoto() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Foto',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Apakah kamu yakin ingin menghapus foto profil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _hapusFoto();
            },
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _hapusFoto() async {
    setState(() => _isUploadingPhoto = true);

    final result = await ApiService.deleteProfilePhoto(userId: widget.userId);

    setState(() => _isUploadingPhoto = false);

    if (!mounted) return;

    if (result['status'] == 'success') {
      setState(() => _currentPhoto = '');
      final session = await UserSession.get();
      if (session != null) {
        await UserSession.save(
          id: session['id'],
          name: session['name'],
          email: session['email'],
          skillLevel: session['skill_level'],
          rememberMe: session['remember_me'],
          fotoProfil: '',
        );
      }
      widget.onPhotoUpdated?.call('');
      _showTopNotif('Foto profil berhasil dihapus');
    } else {
      _showTopNotif(result['message'] ?? 'Gagal menghapus foto', isError: true);
    }
  }

  // ── Logout ────────────────────────────────────────────────────

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Apakah kamu yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await UserSession.clear();
              if (!mounted) return;
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

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── AppBar Biru ──────────────────────────────────
          Container(
            width: double.infinity,
            color: const Color(0xFF2563EB),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 20,
            ),
            child: const Text(
              'Profil',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),

                  // ── Avatar dengan tombol kamera ───────────
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _isUploadingPhoto ? null : _showPhotoOptions,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2563EB),
                                width: 2.5,
                              ),
                              color: const Color(0xFFF3F4F6),
                            ),
                            child: ClipOval(
                              child: _isUploadingPhoto
                                  ? const Center(
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    )
                                  : _photoUrl.isNotEmpty
                                  ? Image.network(
                                      _photoUrl,
                                      fit: BoxFit.cover,
                                      width: 90,
                                      height: 90,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Color(0xFF9CA3AF),
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _isUploadingPhoto ? null : _showPhotoOptions,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Nama Pengguna ─────────────────────────
                  _FieldLabel(text: 'Nama Pengguna'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: _isEditingName
                          ? Border.all(
                              color: const Color(0xFF2563EB),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 14),
                          child: Icon(
                            Icons.person_outline,
                            color: Color(0xFF9CA3AF),
                            size: 20,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            enabled: _isEditingName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A1A2E),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        _isSavingName
                            ? const Padding(
                                padding: EdgeInsets.only(right: 14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                                  child: Icon(
                                    _isEditingName ? Icons.check : Icons.edit,
                                    color: _isEditingName
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF9CA3AF),
                                    size: 20,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Email (read only) ─────────────────────
                  _FieldLabel(text: 'Email'),
                  const SizedBox(height: 8),
                  _ReadOnlyField(
                    icon: Icons.email_outlined,
                    value: widget.userEmail,
                  ),

                  const SizedBox(height: 16),

                  // ── Level (read only) ─────────────────────
                  _FieldLabel(text: 'Level'),
                  const SizedBox(height: 8),
                  _ReadOnlyField(
                    icon: Icons.trending_up_rounded,
                    value: _skillLabel(widget.skillLevel),
                  ),

                  const SizedBox(height: 32),

                  // ── Tombol Ubah Password ──────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UbahPasswordScreen(userId: widget.userId),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Ubah Password',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Tombol Keluar ─────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _confirmLogout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Keluar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
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

// ── Notifikasi Atas (Overlay) ─────────────────────────────────

class _TopNotifWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDone;

  const _TopNotifWidget({
    required this.message,
    required this.isError,
    required this.onDone,
  });

  @override
  State<_TopNotifWidget> createState() => _TopNotifWidgetState();
}

class _TopNotifWidgetState extends State<_TopNotifWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1), // mulai dari atas layar
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    // Masuk
    _ctrl.forward();

    // Tahan 2.5 detik lalu keluar
    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (mounted) {
        await _ctrl.reverse();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: widget.isError
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1A1A2E),
    ),
  );
}

class _ReadOnlyField extends StatelessWidget {
  final IconData icon;
  final String value;
  const _ReadOnlyField({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
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
