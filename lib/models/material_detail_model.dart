class MaterialDetail {
  final String title;
  final String description;
  final String partName;
  final String? imageFile;
  final String? audioFile;

  MaterialDetail({
    required this.title,
    required this.description,
    required this.partName,
    this.imageFile,
    this.audioFile,
  });

  factory MaterialDetail.fromJson(Map<String, dynamic> json) {
    return MaterialDetail(
      title: json['title'] ?? '',
      description: json['text_content'] ?? '',
      partName: json['part_name'] ?? '',
      imageFile: json['image_file'],
      audioFile: json['audio_file'],
    );
  }
}
