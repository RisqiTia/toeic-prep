import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 241, 245, 249), // kotak putih dalam
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            _buildNavItem(Icons.home, 'Beranda', 0),
            _buildNavItem(Icons.history, 'Riwayat', 1),
            _buildNavItem(Icons.account_circle, 'Profil', 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFDBEAFE) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: isActive ? const Color(0xFF2563EB) : Colors.grey[600],
              ),
            ),

            const SizedBox(height: 4),

            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? const Color(0xFF2563EB) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
