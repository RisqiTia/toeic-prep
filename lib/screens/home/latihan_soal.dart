import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:toeic_prep/models/latihan_soal_model.dart';
import 'package:toeic_prep/services/user_session.dart';
import 'package:toeic_prep/screens/home/result_screen.dart';

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
  late Future<List<LatihanSoalModel>> _soalFuture;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  bool _isSubmitting = false; // ← loading saat submit

  int _currentIndex = 0;
  String? _selectedAnswer;
  final Map<int, String> _userAnswers = {};

  // attempt_id dari server saat fetch soal
  int? _attemptId;

  // Untuk Part 3 & 4 — track audio yang sedang aktif
  String? _currentAudioFile;

  static const String _mediaBaseUrl = 'http://10.0.2.2/toeic_dataset_generator';
  static const String _apiBaseUrl   = 'http://10.0.2.2/toeic_prep_app/toeic_api';

  bool get _isListening    => widget.partId >= 1 && widget.partId <= 4;
  bool get _hasImage       => widget.partId == 1;
  bool get _hideOptionText => widget.partId == 1 || widget.partId == 2;

  @override
  void initState() {
    super.initState();
    _soalFuture = _fetchSoal();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) _isLoadingAudio = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Fetch Soal ──────────────────────────────────────────────────────────

  Future<List<LatihanSoalModel>> _fetchSoal() async {
    final session    = await UserSession.get();
    final userId     = session?['id'] ?? widget.userId;
    final skillLevel = session?['skill_level'] ?? 'beginner';

    try {
      final response = await http.get(
        Uri.parse(
          '$_apiBaseUrl/questions.php'
          '?action=practice&part_id=${widget.partId}&user_id=$userId',
        ),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        // Simpan attempt_id dari server
        _attemptId = data['attempt_id'];

        final List allSoal = data['data'];

        final filtered = allSoal
            .where((e) => e['difficulty_level'] == skillLevel)
            .toList();

        if (widget.partId == 3 || widget.partId == 4) {
          return _groupAndLimit(filtered, targetSoal: 12);
        }
        if (widget.partId == 6 || widget.partId == 7) {
          return _groupAndLimit(filtered, targetSoal: 12);
        }

        filtered.shuffle();
        return filtered
            .take(10)
            .map((e) => LatihanSoalModel.fromJson(e))
            .toList();
      } else {
        throw Exception(data['message'] ?? 'Gagal mengambil soal');
      }
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  List<LatihanSoalModel> _groupAndLimit(
    List rawList, {
    required int targetSoal,
  }) {
    final Map<String, List> grouped = {};

    for (final soal in rawList) {
      String groupKey = '';

      if (widget.partId == 3 || widget.partId == 4) {
        groupKey = soal['audio_file'] ?? '';
      } else if (widget.partId == 6 || widget.partId == 7) {
        String question = soal['question_text'] ?? '';
        groupKey = question.length > 50 ? question.substring(0, 50) : question;
      }

      grouped.putIfAbsent(groupKey, () => []).add(soal);
    }

    final groupKeys = grouped.keys.toList()..shuffle();
    final result    = <LatihanSoalModel>[];

    for (final key in groupKeys) {
      result.addAll(grouped[key]!.map((e) => LatihanSoalModel.fromJson(e)));
      if (result.length >= targetSoal) break;
    }

    return result;
  }

  // ─── Submit Jawaban ke Server ─────────────────────────────────────────────

  Future<void> _submitAnswers(List<LatihanSoalModel> soalList) async {
    if (_attemptId == null) {
      // Fallback: langsung hitung skor lokal jika tidak ada attempt_id
      _goToResult(soalList, _calculateScore(soalList));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Susun array jawaban
      final answers = <Map<String, dynamic>>[];
      for (int i = 0; i < soalList.length; i++) {
        final soal       = soalList[i];
        final userAnswer = _userAnswers[i] ?? '';
        final isCorrect  = userAnswer == soal.correctAnswer;

        answers.add({
          'question_id': soal.id,
          'user_answer': userAnswer,
          'is_correct' : isCorrect,
        });
      }

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/scores.php?action=save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'attempt_id': _attemptId,
          'answers'   : answers,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        // Hitung skor dari akurasi yang dikembalikan server
        final accuracy = (data['accuracy'] as num?)?.toInt()
            ?? _calculateScore(soalList);
        _goToResult(soalList, accuracy);
      } else {
        // Kalau server error, tetap tampilkan hasil lokal
        _goToResult(soalList, _calculateScore(soalList));
      }
    } catch (e) {
      debugPrint('❌ Submit error: $e');
      // Tetap lanjutkan meski gagal simpan
      _goToResult(soalList, _calculateScore(soalList));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goToResult(List<LatihanSoalModel> soalList, int score) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(score: score),
      ),
    );
  }

  // ─── Hitung Skor Lokal (fallback) ────────────────────────────────────────

  int _calculateScore(List<LatihanSoalModel> soalList) {
    int correct = 0;
    for (int i = 0; i < soalList.length; i++) {
      if (_userAnswers[i] == soalList[i].correctAnswer) correct++;
    }
    return ((correct / soalList.length) * 100).round();
  }

  // ─── Audio ───────────────────────────────────────────────────────────────

  Future<void> _toggleAudio(String audioFile) async {
    if (_currentAudioFile != audioFile) {
      await _audioPlayer.stop();
      _currentAudioFile = audioFile;
      setState(() {
        _isPlaying       = false;
        _isLoadingAudio  = true;
      });
      try {
        await _audioPlayer.setSourceUrl('$_mediaBaseUrl/$audioFile');
        await _audioPlayer.resume();
        setState(() => _isLoadingAudio = false);
      } catch (e) {
        debugPrint('❌ Audio error: $e');
        setState(() => _isLoadingAudio = false);
      }
      return;
    }

    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isLoadingAudio = true);
      try {
        await _audioPlayer.resume();
        setState(() => _isLoadingAudio = false);
      } catch (e) {
        debugPrint('❌ Audio error: $e');
        setState(() => _isLoadingAudio = false);
      }
    }
  }

  // ─── Navigasi Soal ───────────────────────────────────────────────────────

  void _goNext(List<LatihanSoalModel> soalList) {
    if (_currentIndex < soalList.length - 1) {
      final nextSoal = soalList[_currentIndex + 1];
      if (nextSoal.audioFile != _currentAudioFile) {
        _audioPlayer.stop();
        setState(() {
          _isPlaying        = false;
          _currentAudioFile = null;
        });
      }
      setState(() {
        _currentIndex++;
        _selectedAnswer = _userAnswers[_currentIndex];
      });
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _selectedAnswer = _userAnswers[_currentIndex];
      });
    }
  }

  void _selectAnswer(String answer) {
    setState(() {
      _selectedAnswer          = answer;
      _userAnswers[_currentIndex] = answer;
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<List<LatihanSoalModel>>(
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
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() => _soalFuture = _fetchSoal()),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          final soalList = snapshot.data!;
          if (soalList.isEmpty) {
            return const Center(
              child: Text('Soal tidak tersedia untuk level ini.'),
            );
          }

          final soal = soalList[_currentIndex];
          final total = soalList.length;

          return SafeArea(
            child: Column(
              children: [
                // ── Top Bar ────────────────────────────────────────────────
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

                // ── Konten Soal ────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── GAMBAR (Part 1)
                        if (_hasImage &&
                            soal.imageFile != null &&
                            soal.imageFile!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              '$_mediaBaseUrl/${soal.imageFile}',
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  height: 220,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (_, _, _) => Container(
                                height: 220,
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

                        if (_hasImage &&
                            soal.imageFile != null &&
                            soal.imageFile!.isNotEmpty)
                          const SizedBox(height: 16),

                        // ── AUDIO PLAYER (Part 1-4)
                        if (_isListening &&
                            soal.audioFile != null &&
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
                                  _isLoadingAudio
                                      ? const SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF2563EB),
                                          ),
                                        )
                                      : Icon(
                                          _isPlaying
                                              ? Icons.pause_circle_filled
                                              : Icons.play_circle_filled,
                                          color: const Color(0xFF2563EB),
                                          size: 32,
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
                                            color: _isPlaying
                                                ? const Color(0xFF2563EB)
                                                : Colors.grey[400],
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (_isListening &&
                            soal.audioFile != null &&
                            soal.audioFile!.isNotEmpty)
                          const SizedBox(height: 20),

                        // ── TEKS SOAL (Part 3-7)
                        if (!_hideOptionText && soal.questionText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              soal.questionText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                height: 1.6,
                              ),
                            ),
                          ),

                        // ── PILIHAN JAWABAN
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
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: _hideOptionText ? 12 : 16,
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
                                    width: 36,
                                    height: 36,
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
                                          fontSize: 15,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!_hideOptionText) ...[
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
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // ── Bottom Button ──────────────────────────────────────────
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
                          onPressed: _currentIndex > 0 && !_isSubmitting
                              ? () => _goPrev()
                              : null,
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
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  if (_currentIndex < soalList.length - 1) {
                                    _goNext(soalList);
                                  } else {
                                    // Soal terakhir → submit ke server
                                    _submitAnswers(soalList);
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
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
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