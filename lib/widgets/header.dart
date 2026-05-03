import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const Header({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: const BoxDecoration(color: Color(0xFF2563EB)),
      child: SafeArea(
        child: Row(
          children: [
            // Back Button
            GestureDetector(
              onTap: onBack ?? () => Navigator.pop(context),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Title
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 24), // penyeimbang icon back
          ],
        ),
      ),
    );
  }
}
