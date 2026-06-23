import 'package:flutter/material.dart';

class LatihanItem {
  final int partNumber;
  final String title;
  final String description;
  final IconData icon;

  LatihanItem({
    required this.partNumber,
    required this.title,
    required this.description,
    required this.icon,
  });
}

final List<LatihanItem> latihanList = [
  LatihanItem(
    partNumber: 1,
    title: 'Part 1 : Photograph',
    description: 'Dengarkan dan pilih deskripsi gambar yang paling sesuai.',
    icon: Icons.image,
  ),
  LatihanItem(
    partNumber: 2,
    title: 'Part 2 : Question Response',
    description: 'Dengarkan pertanyaan dan pilih jawaban yang tepat.',
    icon: Icons.question_answer,
  ),
  LatihanItem(
    partNumber: 3,
    title: 'Part 3 : Conversation',
    description: 'Dengarkan percakapan dan jawab pertanyaannya.',
    icon: Icons.people,
  ),
  LatihanItem(
    partNumber: 4,
    title: 'Part 4 : Talks',
    description: 'Dengarkan penjelasan dan temukan informasi penting.',
    icon: Icons.radio,
  ),
  LatihanItem(
    partNumber: 5,
    title: 'Part 5 : Incomplete Sentence',
    description: 'Pilih jawaban yang tepat untuk melengkapi kalimat.',
    icon: Icons.subject,
  ),
  LatihanItem(
    partNumber: 6,
    title: 'Part 6 : Text Completion',
    description: 'Lengkapi teks dengan kata atau kalimat yang sesuai.',
    icon: Icons.article,
  ),
  LatihanItem(
    partNumber: 7,
    title: 'Part 7 : Reading Comprehension',
    description: 'Baca teks dan jawab pertanyaan yang diberikan.',
    icon: Icons.library_books,
  ),
];
