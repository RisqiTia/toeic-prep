import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';

class SkillLevelScreen extends StatefulWidget {
  final String name;
  final String email;

  const SkillLevelScreen({super.key, required this.name, required this.email});

  @override
  State<SkillLevelScreen> createState() => _SkillLevelScreenState();
}

class _SkillLevelScreenState extends State<SkillLevelScreen> {
  // 'beginner' | 'intermediate' | 'advanced'
  String? _selectedLevel;
  bool _isLoading = false;
  String? _errorMessage;

  final _levels = [
    {
      'value': 'beginner',
      'label': 'Pemula',
      'description': 'Saya dapat memahami kata-kata dan kalimat dasar.',
    },
    {
      'value': 'intermediate',
      'label': 'Menengah',
      'description': 'Saya memahami sebagian besar topik umum.',
    },
    {
      'value': 'advanced',
      'label': 'Mahir',
      'description': 'Saya memahami bahasa Inggris akademik dan profesional.',
    },
  ];

  Future<void> _handleDaftar() async {
    if (_selectedLevel == null) {
      setState(
        () => _errorMessage = 'Pilih tingkat kemampuan kamu terlebih dahulu',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Update skill_level user di database
    final result = await ApiService.updateSkillLevel(
      email: widget.email,
      skillLevel: _selectedLevel!,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['status'] == 'success') {
      // Berhasil → ke halaman login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pendaftaran berhasil! Silakan login.'),
          backgroundColor: Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } else {
      setState(() => _errorMessage = result['message'] ?? 'Terjadi kesalahan');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ── Judul ─────────────────────────────────────
              const Text(
                'Seberapa baik Anda\nmemahami bahasa Inggris?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                'Pilih tingkat yang paling sesuai dengan kemampuan Anda saat ini untuk menyesuaikan jalur belajar Anda.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // ── Error ──────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Pilihan Level ──────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: _levels.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final level = _levels[i];
                    final selected = _selectedLevel == level['value'];

                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedLevel = level['value']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF2563EB)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    level['label']!,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    level['description']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Radio button
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF2563EB)
                                      : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                              child: selected
                                  ? Center(
                                      child: Container(
                                        width: 11,
                                        height: 11,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ── Tombol Daftar ──────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleDaftar,
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
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Daftar',
                          style: TextStyle(
                            fontSize: 16,
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
    );
  }
}
