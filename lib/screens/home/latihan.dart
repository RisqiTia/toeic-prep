import 'package:flutter/material.dart';
import 'package:toeic_prep/models/latihan_model.dart';
import 'package:toeic_prep/widgets/materi_card.dart';
import 'package:toeic_prep/widgets/header.dart';

class LatihanScreen extends StatelessWidget {
  const LatihanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Header(title: 'Latihan TOEIC'),

          // Latihan List
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
                  onTap: () {
                    // TODO: nanti arahkan ke halaman soal latihan
                    // Navigator.push(context, MaterialPageRoute(
                    //   builder: (context) => LatihanSoalScreen(
                    //     partId: latihan.partNumber,
                    //     partName: latihan.title,
                    //   ),
                    // ));
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
