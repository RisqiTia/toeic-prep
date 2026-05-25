import 'package:flutter/material.dart';
import 'package:toeic_prep/models/latihan_model.dart';
import 'package:toeic_prep/widgets/materi_card.dart';
import 'package:toeic_prep/widgets/header.dart';
import 'package:toeic_prep/screens/home/latihan_soal.dart';
import 'package:toeic_prep/services/user_session.dart';

class LatihanScreen extends StatelessWidget {
  const LatihanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Header(title: 'Latihan TOEIC'),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: latihanList.length,
              itemBuilder: (context, index) {
                final latihan = latihanList[index];
                return MateriCard(
                  partNumber: latihan.partNumber,
                  title: latihan.title,
                  description: latihan.description,
                  icon: latihan.icon,
                  onTap: () async {
                    final session = await UserSession.get();
                    final userId = session?['id'] ?? 0;

                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LatihanSoal(
                            partId: latihan.partNumber,
                            partName: latihan.title,
                            userId: userId,
                          ),
                        ),
                      );
                    }
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