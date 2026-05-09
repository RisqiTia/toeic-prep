import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:toeic_prep/models/latihan_soal_model.dart';

class LatihanSoal extends StatefulWidget {
  final int partId;
  final String partName;
  final int userId;

  const LatihanSoal({
    super.key,
    required this.partId,
    required this.partName,
    required this.userId,
  });

  @override
  State<LatihanSoal> createState() => _LatihanSoalState();
}

class _LatihanSoalState extends State<LatihanSoal> {
  late Future<Map<String, dynamic>> _soalFuture;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  int _currentIndex = 0;
  String? _selectedAnswer;
  final Map<int, String> _userAnswers = {};

  static const String _mediaBaseUrl = 'http://10.0.2.2/toeic_dataset_generator';

  @override
  void initState() {
    super.initState();
    _soalFuture = _fetchSoal();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchSoal() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'status': 'success',
      'attempt_id': 0,
      'data': [
        {
          'id': '1',
          'part_id': widget.partId.toString(),
          'question_text':
              'Look at the picture and choose the statement that best describes it.',
          'option_a': 'The woman is holding a cup of coffee.',
          'option_b': 'She is writing in a notebook.',
          'option_c': 'The office is brightly lit.',
          'option_d': 'She is sitting by the window.',
          'correct_answer': 'A',
          'explanation': 'The woman is holding a cup of coffee.',
          'image_file': '',
          'audio_file': '',
        },
        {
          'id': '2',
          'part_id': widget.partId.toString(),
          'question_text': 'Where is the meeting scheduled?',
          'option_a': 'In the conference room.',
          'option_b': 'In the cafeteria.',
          'option_c': 'In the parking lot.',
          'option_d': 'In the lobby.',
          'correct_answer': 'A',
          'explanation': 'The meeting is in the conference room.',
          'image_file': '',
          'audio_file': '',
        },
        {
          'id': '3',
          'part_id': widget.partId.toString(),
          'question_text': 'What does the man suggest doing?',
          'option_a': 'Calling the client.',
          'option_b': 'Sending an email.',
          'option_c': 'Scheduling a meeting.',
          'option_d': 'Writing a report.',
          'correct_answer': 'B',
          'explanation': 'The man suggests sending an email.',
          'image_file': '',
          'audio_file': '',
        },
        {
          'id': '4',
          'part_id': widget.partId.toString(),
          'question_text': 'What time does the store close?',
          'option_a': 'At 8 PM.',
          'option_b': 'At 9 PM.',
          'option_c': 'At 10 PM.',
          'option_d': 'At 11 PM.',
          'correct_answer': 'C',
          'explanation': 'The store closes at 10 PM.',
          'image_file': '',
          'audio_file': '',
        },
        {
          'id': '5',
          'part_id': widget.partId.toString(),
          'question_text': 'Who is responsible for the project?',
          'option_a': 'The manager.',
          'option_b': 'The assistant.',
          'option_c': 'The client.',
          'option_d': 'The director.',
          'correct_answer': 'A',
          'explanation': 'The manager is responsible.',
          'image_file': '',
          'audio_file': '',
        },
        {
          'id': '6',
          'part_id': widget.partId.toString(),
          'question_text': 'What is the purpose of the announcement?',
          'option_a': 'To inform about a schedule change.',
          'option_b': 'To advertise a new product.',
          'option_c': 'To introduce a new employee.',
          'option_d': 'To announce a holiday.',
          'correct_answer': 'A',
          'explanation': 'The announcement is about a schedule change.',
          'image_file': '',
          'audio_file': '',
        },
        {
          'id': '7',
          'part_id': widget.partId.toString(),
          'question_text': 'Where does the conversation take place?',
          'option_a': 'At a restaurant.',
          'option_b': 'At a hotel.',
          'option_c': 'At an airport.',
          'option_d': 'At an office.',
          'correct_answer': 'B',
          'explanation': 'The conversation takes place at a hotel.',
          'image_file': '',
          'audio_file': '',
        },
        {
          'id': '8',
          'part_id': widget.partId.toString(),
          'question_text': 'What will the speakers do next?',
          'option_a': 'Go to lunch.',
          'option_b': 'Attend a meeting.',
          'option_c': 'Call a client.',
          'option_d': 'Review a report.',
          'correct_answer': 'B',
          'explanation': 'They will attend a meeting.',
          'image_file': '',
          'audio_file': '',
        },
        {
          'id': '9',
          'part_id': widget.partId.toString(),
          'question_text': 'How many people attended the conference?',
          'option_a': 'About 50.',
          'option_b': 'About 100.',
          'option_c': 'About 200.',
          'option_d': 'About 300.',
          'correct_answer': 'C',
          'explanation': 'About 200 people attended.',
          'image_file': '',
          'audio_file': '',
        },
        {
          'id': '10',
          'part_id': widget.partId.toString(),
          'question_text': 'What is being discussed in the email?',
          'option_a': 'A job application.',
          'option_b': 'A budget proposal.',
          'option_c': 'A travel itinerary.',
          'option_d': 'A product order.',
          'correct_answer': 'B',
          'explanation': 'The email discusses a budget proposal.',
          'image_file': '',
          'audio_file': '',
        },
      ],
    };
  }

  Future<void> _toggleAudio(String audioFile) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource('$_mediaBaseUrl/$audioFile'));
    }
  }

  void _goNext(List<LatihanSoalModel> soalList) {
    if (_currentIndex < soalList.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = _userAnswers[_currentIndex];
      });
      _audioPlayer.stop();
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _selectedAnswer = _userAnswers[_currentIndex];
      });
      _audioPlayer.stop();
    }
  }

  void _selectAnswer(String answer) {
    setState(() {
      _selectedAnswer = answer;
      _userAnswers[_currentIndex] = answer;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _soalFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() => _soalFuture = _fetchSoal()),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final List rawList = data['data'];
          final soalList = rawList
              .map((e) => LatihanSoalModel.fromJson(e))
              .toList();
          final soal = soalList[_currentIndex];
          final total = soalList.length;

          return SafeArea(
            child: Column(
              children: [
                // ── Top Bar ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close, size: 20),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (_currentIndex + 1) / total,
                              backgroundColor: Colors.grey[200],
                              color: const Color(0xFF2563EB),
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Question ${_currentIndex + 1} of $total',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Konten Soal ──────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gambar
                        if (soal.imageFile != null &&
                            soal.imageFile!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              '$_mediaBaseUrl/${soal.imageFile}',
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                height: 200,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        if (soal.imageFile != null &&
                            soal.imageFile!.isNotEmpty)
                          const SizedBox(height: 16),

                        // Audio player
                        if (soal.audioFile != null &&
                            soal.audioFile!.isNotEmpty)
                          GestureDetector(
                            onTap: () => _toggleAudio(soal.audioFile!),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    color: const Color(0xFF2563EB),
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: List.generate(
                                        30,
                                        (i) => Container(
                                          width: 2.5,
                                          height: (i % 3 == 0)
                                              ? 20
                                              : (i % 2 == 0)
                                              ? 14
                                              : 8,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[400],
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (soal.audioFile != null &&
                            soal.audioFile!.isNotEmpty)
                          const SizedBox(height: 16),

                        // Teks soal
                        if (soal.questionText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              soal.questionText,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                height: 1.6,
                              ),
                            ),
                          ),

                        // Pilihan A/B/C/D
                        ...['A', 'B', 'C', 'D'].map((key) {
                          final text = key == 'A'
                              ? soal.optionA
                              : key == 'B'
                              ? soal.optionB
                              : key == 'C'
                              ? soal.optionC
                              : soal.optionD;
                          final isSelected = _selectedAnswer == key;

                          return GestureDetector(
                            onTap: () => _selectAnswer(key),
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue[50]
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey[100],
                                    ),
                                    child: Center(
                                      child: Text(
                                        key,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // ── Bottom Button ─────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _currentIndex > 0 ? () => _goPrev() : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: const Text(
                            'Sebelumnya',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentIndex < soalList.length - 1) {
                              _goNext(soalList);
                            } else {
                              // TODO: ke halaman hasil
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _currentIndex < soalList.length - 1
                                ? 'Selanjutnya'
                                : 'Selesai',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
