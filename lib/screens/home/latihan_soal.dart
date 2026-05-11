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

  int _currentIndex = 0;
  String? _selectedAnswer;
  final Map<int, String> _userAnswers = {};

  // Untuk Part 3 & 4 — track audio yang sedang aktif
  String? _currentAudioFile;

  static const String _mediaBaseUrl = 'http://10.0.2.2/toeic_dataset_generator';
  static const String _apiBaseUrl = 'http://10.0.2.2/toeic_prep_app/toeic_api';

  // Part listening
  bool get _isListening => widget.partId >= 1 && widget.partId <= 4;
  // Part yang tampilkan gambar
  bool get _hasImage => widget.partId == 1;
  // Part yang sembunyikan teks opsi
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

  Future<List<LatihanSoalModel>> _fetchSoal() async {
    final session = await UserSession.get();
    final userId = session?['id'] ?? widget.userId;
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
        final List allSoal = data['data'];

        // Filter berdasarkan level user
        final filtered = allSoal
            .where((e) => e['difficulty_level'] == skillLevel)
            .toList();

        // Untuk Part 3 & 4 — kelompokkan berdasarkan audio
        // lalu ambil max 4 grup (10 soal)
        if (widget.partId == 3 || widget.partId == 4) {
          return _groupAndLimitPart34(filtered);
        }

        // Part lain — acak dan ambil 10
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

  // Kelompokkan soal Part 3 & 4 berdasarkan audio_file yang sama
  List<LatihanSoalModel> _groupAndLimitPart34(List rawList) {
    // Kelompokkan berdasarkan audio_file
    final Map<String, List> grouped = {};
    for (final soal in rawList) {
      final audio = soal['audio_file'] ?? '';
      grouped.putIfAbsent(audio, () => []).add(soal);
    }

    // Ambil max 4 grup (acak)
    final groupKeys = grouped.keys.toList()..shuffle();
    final selectedKeys = groupKeys.take(4);

    // Gabungkan soal dari grup yang dipilih
    final result = <LatihanSoalModel>[];
    for (final key in selectedKeys) {
      for (final soal in grouped[key]!) {
        result.add(LatihanSoalModel.fromJson(soal));
      }
    }
    return result;
  }

  Future<void> _toggleAudio(String audioFile) async {
    // Jika ganti audio (soal berbeda)
    if (_currentAudioFile != audioFile) {
      await _audioPlayer.stop();
      _currentAudioFile = audioFile;
      setState(() {
        _isPlaying = false;
        _isLoadingAudio = true;
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

    // Toggle play/pause audio yang sama
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

  void _goNext(List<LatihanSoalModel> soalList) {
    if (_currentIndex < soalList.length - 1) {
      final nextSoal = soalList[_currentIndex + 1];
      // Jika soal berikutnya audio berbeda → stop audio
      if (nextSoal.audioFile != _currentAudioFile) {
        _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
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
      _selectedAnswer = answer;
      _userAnswers[_currentIndex] = answer;
    });
  }

  int _calculateScore(List<LatihanSoalModel> soalList) {
    int correct = 0;

    for (int i = 0; i < soalList.length; i++) {
      final soal = soalList[i];

      // Jawaban user
      final userAnswer = _userAnswers[i];

      // Jawaban benar dari database
      final correctAnswer = soal.correctAnswer;

      if (userAnswer == correctAnswer) {
        correct++;
      }
    }

    // Konversi ke nilai 0-100
    int finalScore = ((correct / soalList.length) * 100).round();

    return finalScore;
  }

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
                        // ── GAMBAR (Part 1 saja)
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

                        if (_isListening &&
                            soal.audioFile != null &&
                            soal.audioFile!.isNotEmpty)
                          const SizedBox(height: 20),

                        // ── TEKS SOAL
                        // Part 1 & 2: sembunyikan teks soal
                        // Part 3-7: tampilkan teks soal
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

                        // Untuk Part 3 & 4 tampilkan teks soal
                        if ((widget.partId == 3 || widget.partId == 4) &&
                            soal.questionText.isNotEmpty)
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
                                // Jika hide text, padding lebih kecil
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
                                  // Bulatan A/B/C/D
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

                                  // Teks opsi — hanya tampil untuk Part 3-7
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
                              // Hitung skor
                              int finalScore = _calculateScore(soalList);

                              // Pindah ke halaman hasil
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ResultScreen(score: finalScore),
                                ),
                              );
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
