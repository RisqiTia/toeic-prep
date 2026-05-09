class LatihanSoal {
  final int id;
  final int partId;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctAnswer;
  final String explanation;
  final String? imageFile;
  final String? audioFile;

  LatihanSoal({
    required this.id,
    required this.partId,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
    required this.explanation,
    this.imageFile,
    this.audioFile,
  });

  factory LatihanSoal.fromMap(Map<String, dynamic> json) {
    return LatihanSoal(
      id: int.parse(json['id'].toString()),
      partId: int.parse(json['part_id'].toString()),
      questionText: json['question_text'] ?? '',
      optionA: json['option_a'] ?? '',
      optionB: json['option_b'] ?? '',
      optionC: json['option_c'] ?? '',
      optionD: json['option_d'] ?? '',
      correctAnswer: json['correct_answer'] ?? '',
      explanation: json['explanation'] ?? '',
      imageFile: json['image_file'],
      audioFile: json['audio_file'],
    );
  }
}
