import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:toeic_prep/widgets/header.dart';

class ResultScreen extends StatelessWidget {
  final int score;

  const ResultScreen({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    // Pastikan nilai tidak lebih dari 100
    double percentage = (score.clamp(0, 100)) / 100;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      body: Column(
        children: [
          // HEADER DARI header.dart
          Header(
            title: 'HASIL LATIHAN',
            onBack: () {
              Navigator.pop(context);
            },
          ),

          // CONTENT
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // CIRCLE SCORE
                  CircularPercentIndicator(
                    radius: 150,
                    lineWidth: 22,
                    animation: true,
                    animationDuration: 1200,
                    percent: percentage,
                    circularStrokeCap: CircularStrokeCap.round,
                    backgroundColor: const Color(0xFFE5E7EB),
                    progressColor: const Color(0xFF2563EB),

                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 48,
                          color: const Color(0xFFFFD700),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          '$score',
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          'SKOR ANDA',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // BUTTON CEK JAWABAN
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // TODO:
                        // Navigasi ke halaman pembahasan jawaban
                      },
                      child: const Text(
                        'Periksa Jawaban',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // BUTTON KEMBALI
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Kembali ke Beranda',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
