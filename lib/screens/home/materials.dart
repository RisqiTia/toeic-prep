import 'package:flutter/material.dart';
import 'package:toeic_prep/models/materi_model.dart';
import 'package:toeic_prep/widgets/materi_card.dart';

class MaterialsScreen extends StatelessWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Header dengan background biru
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: const BoxDecoration(color: Color(0xFF2563EB)),
            child: SafeArea(
              child: Row(
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title
                  Expanded(
                    child: const Text(
                      'Materi TOEIC',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
          ),
          // Materi List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: materiList.length,
              itemBuilder: (context, index) {
                final materi = materiList[index];
                return MateriCard(
                  partNumber: materi.partNumber,
                  title: materi.title,
                  description: materi.description,
                  icon: materi.icon,
                  onTap: () {},
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
