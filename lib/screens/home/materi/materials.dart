import 'package:flutter/material.dart';
import 'package:toeic_prep/models/materi_model.dart';
import 'package:toeic_prep/widgets/materi_card.dart';
import 'package:toeic_prep/screens/home/materi/material_detail.dart';
import 'package:toeic_prep/widgets/header.dart';

class MaterialsScreen extends StatelessWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Header(title: 'Materi TOEIC'),

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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MaterialDetailScreen(
                          partId: materi.partNumber,
                          partName: materi.title,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
