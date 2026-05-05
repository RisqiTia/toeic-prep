import 'package:flutter/material.dart';

class MateriItem {
  final int partNumber;
  final String title;
  final String description;
  final IconData icon;

  MateriItem({
    required this.partNumber,
    required this.title,
    required this.description,
    required this.icon,
  });
}

// Data materi TOEIC
final List<MateriItem> materiList = [
  MateriItem(
    partNumber: 1,
    title: 'Part 1: Photograph',
    description:
        'Pelajari cara memahami gambar\ndan deskripsinya dengan tepat.',
    icon: Icons.image,
  ),
  MateriItem(
    partNumber: 2,
    title: 'Part 2: Question Response',
    description:
        'Pelajari cara memahami\npertanyaan dan memilih respons\nyang sesuai.',
    icon: Icons.question_answer,
  ),
  MateriItem(
    partNumber: 3,
    title: 'Part 3: Conversation',
    description: 'Pahami percakapan dan cara\nmenangkap informasi penting.',
    icon: Icons.people,
  ),
  MateriItem(
    partNumber: 4,
    title: 'Part 4: Talks',
    description:
        'Pahami monolog atau penjelasan\nssingkat dalam bahasa inggris.',
    icon: Icons.radio,
  ),
  MateriItem(
    partNumber: 5,
    title: 'Part 5: Incomplete Sentence',
    description: 'Pelajari struktur kalimat dan tata\nbahasa dasar.',
    icon: Icons.subject,
  ),
  MateriItem(
    partNumber: 6,
    title: 'Part 6: Text Completion',
    description: 'Pahami konteks teks untuk\nmelengkapi kalimat dengan tepat.',
    icon: Icons.article,
  ),
  MateriItem(
    partNumber: 7,
    title: 'Part 7: Reading Comprehension',
    description: 'Pahami isi teks dan cara\nmenemukan informasi penting.',
    icon: Icons.library_books,
  ),
];
