import 'package:flutter/material.dart';
import 'package:toeic_prep/screens/home/materials.dart';
import 'package:toeic_prep/widgets/widgets.dart';
import 'package:toeic_prep/screens/home/latihan.dart';

class BerandaScreen extends StatefulWidget {
  final String userName;

  const BerandaScreen({super.key, required this.userName});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_currentIndex == 0) {
      return _buildBerandaContent();
    } else if (_currentIndex == 1) {
      return const Center(child: Text('Riwayat Page'));
    } else {
      return const Center(child: Text('Profil Page'));
    }
  }

  Widget _buildBerandaContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Header Greeting
            Text(
              'Halo, ${widget.userName}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Mari kita berlatih TOEIC secara bertahap\ndan tingkatkan kemampuan bahasa\nInggris Anda setiap hari.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Menu Cards
            MenuCard(
              icon: Icons.book,
              title: 'Materi TOEIC',
              description:
                  'Tingkatkan kemampuan Listening\ndan Reading secara bertahap.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MaterialsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            MenuCard(
              icon: Icons.lightbulb,
              title: 'Latihan TOEIC',
              description:
                  'Latihan soal TOEIC per part untuk\nmengasah Listening dan Reading.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LatihanScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            MenuCard(
              icon: Icons.access_time,
              title: 'Tes Simulasi',
              description: 'Uji coba lengkap dalam bentuk\nujian simulasi',
              onTap: () {
                // Navigate ke Tes Simulasi
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
