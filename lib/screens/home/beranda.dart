import 'package:flutter/material.dart';
import 'package:toeic_prep/screens/home/materi/materials.dart';
import 'package:toeic_prep/screens/home/latihan/latihan.dart';
import 'package:toeic_prep/screens/riwayat/riwayat_screen.dart';
import 'package:toeic_prep/screens/profile/profil_screen.dart';
import 'package:toeic_prep/widgets/bottom_navbar.dart';
import 'package:toeic_prep/widgets/menu_card.dart';
import 'package:toeic_prep/widgets/simulasi_confirm_dialog.dart';
import 'package:toeic_prep/services/api_service.dart';

class BerandaScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String userEmail;
  final String skillLevel;
  final String userPhoto;

  const BerandaScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.skillLevel,
    this.userPhoto = '',
  });

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  int _currentIndex = 0;

  late String _userName;
  late String _userPhoto;

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _userPhoto = widget.userPhoto;
  }

  String get _photoUrl {
    if (_userPhoto.isEmpty) return '';
    return '${ApiService.mediaBaseUrl}/uploads/profil/$_userPhoto';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(),
      bottomNavigationBar: Container(
        child: CustomBottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_currentIndex == 0) {
      return _buildBerandaContent();
    } else if (_currentIndex == 1) {
      return const RiwayatScreen();
    } else {
      return ProfilScreen(
        userId: widget.userId,
        userName: _userName,
        userEmail: widget.userEmail,
        skillLevel: widget.skillLevel,
        userPhoto: _userPhoto,
        onNameUpdated: (newName) => setState(() => _userName = newName),
        onPhotoUpdated: (newPhoto) => setState(() => _userPhoto = newPhoto),
      );
    }
  }

  Widget _buildBerandaContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // ── Header: Greeting kiri, Avatar kanan ──────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Halo, $_userName ',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              GestureDetector(
                onTap: () => setState(() => _currentIndex = 2),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2563EB),
                      width: 2,
                    ),
                    color: const Color(0xFFF3F4F6),
                  ),
                  child: ClipOval(
                    child: _photoUrl.isNotEmpty
                        ? Image.network(
                            _photoUrl,
                            fit: BoxFit.cover,
                            width: 44,
                            height: 44,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.person,
                              size: 26,
                              color: Color(0xFF9CA3AF),
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 26,
                            color: Color(0xFF9CA3AF),
                          ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            'Mari kita berlatih TOEIC secara bertahap\ndan tingkatkan kemampuan bahasa\nInggris Anda setiap hari.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // ── Menu Cards ───────────────────────────────────
          MenuCard(
            icon: Icons.book,
            title: 'Materi TOEIC',
            description:
                'Tingkatkan kemampuan Listening\ndan Reading secara bertahap.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MaterialsScreen()),
            ),
          ),

          const SizedBox(height: 16),

          MenuCard(
            icon: Icons.lightbulb,
            title: 'Latihan TOEIC',
            description:
                'Latihan soal TOEIC per part untuk\nmengasah Listening dan Reading.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LatihanScreen()),
            ),
          ),

          const SizedBox(height: 16),

          MenuCard(
            icon: Icons.access_time,
            title: 'Tes Simulasi',
            description: 'Uji coba lengkap dalam bentuk\nujian simulasi',
            onTap: () => showDialog(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.5),
              builder: (_) => const SimulasiConfirmDialog(),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}