import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:toeic_prep/models/latihan_soal_model.dart';
import 'package:toeic_prep/services/user_session.dart';
import 'package:toeic_prep/screens/home/simulasi/simulasi_result_screen.dart';
import 'package:toeic_prep/services/api_service.dart';

class SimulasiScreen extends StatefulWidget {
  final int userId;

  const SimulasiScreen({super.key, required this.userId});

  @override
  State<SimulasiScreen> createState() => _SimulasiScreenState();
}

class _SimulasiScreenState extends State<SimulasiScreen> {
  late Future<List<LatihanSoalModel>> _soalFuture;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  String? _currentAudioFile;
  bool _audioCompleted = false;

  int _currentIndex = 0;
  final Map<int, String> _userAnswers = {};
  String? _selectedAnswer;

  bool _showQuestionList = false;
  final ScrollController _questionScrollController = ScrollController();
  bool _isSubmitting = false;

  late Timer _timer;
  int _remainingSeconds = 120 * 60;

  @override
  void initState() {
    super.initState();
    _soalFuture = _fetchSoal();
    _startTimer();

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
      });

      _audioCompleted = true;
    });

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
    _timer.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
        _timer.cancel();
        _submitSimulasi();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String get _timerText {
    final h = _remainingSeconds ~/ 3600;
    final m = (_remainingSeconds % 3600) ~/ 60;
    final s = _remainingSeconds % 60;
    return '${h.toString().padLeft(1, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int? _attemptId;

  // Fetch simulation questions
  Future<List<LatihanSoalModel>> _fetchSoal() async {
    final session = await UserSession.get();
    final userId = session?['id'] ?? widget.userId;

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.apiBaseUrl}/questions.php?action=simulation&user_id=$userId',
        ),
      );
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _attemptId = data['attempt_id'];
        final List raw = data['data'];
        return raw.map((e) => LatihanSoalModel.fromJson(e)).toList();
      } else {
        throw Exception(data['message'] ?? 'Gagal mengambil soal');
      }
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  // Submit simulation result
  void _submitSimulasi() {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });

    _soalFuture.then((soalList) async {
      int listeningScore = 0;
      int readingScore = 0;
      int totalScore = 0;
      String motivation = '';
      List<WeakPartInfo> weakParts = []; // ← BARU
      bool saveSuccess = true;

      // Simpan ke database
      if (_attemptId != null) {
        try {
          final answers = <Map<String, dynamic>>[];

          for (int i = 0; i < soalList.length; i++) {
            answers.add({
              'question_id': soalList[i].id,
              'user_answer': _userAnswers[i] ?? '',
              'is_correct':
                  (_userAnswers[i] ?? '') == soalList[i].correctAnswer,
            });
          }

          final response = await http.post(
            Uri.parse('${ApiService.apiBaseUrl}/scores.php?action=save'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'attempt_id': _attemptId, 'answers': answers}),
          );

          final result = jsonDecode(response.body);
          listeningScore = result['listening_score'] ?? 0;
          readingScore = result['reading_score'] ?? 0;
          totalScore = result['total_score'] ?? 0;
          motivation = result['motivation'] ?? '';

          // ── BARU: ambil daftar part lemah dari response ──────────────
          final List rawWeakParts = result['weak_parts'] ?? [];
          weakParts = rawWeakParts
              .map((e) => WeakPartInfo.fromJson(e as Map<String, dynamic>))
              .toList();
          // ─────────────────────────────────────────────────────────────

          debugPrint(response.body);
        } catch (e) {
          saveSuccess = false;
          setState(() {
            _isSubmitting = false;
          });

          debugPrint('Save simulasi error: $e');
        }
      }

      if (!saveSuccess) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan hasil simulasi')),
        );

        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SimulasiResultScreen(
            totalScore: totalScore,
            listeningScore: listeningScore,
            readingScore: readingScore,
            userId: widget.userId,
            soalList: soalList,
            userAnswers: Map.from(_userAnswers),
            motivation: motivation,
            weakParts: weakParts, // ← BARU
          ),
        ),
      );
    });
  }

  void _showSubmitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SELESAIKAN SIMULASI',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Kamu bisa menyelesaikan simulasi sekarang atau memeriksa kembali jawabanmu sebelum dikirim.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Color.fromARGB(255, 196, 194, 194),
                        ),
                      ),
                      child: const Text(
                        'Cek Kembali',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _timer.cancel();
                              _submitSimulasi();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Kirim',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluar Simulasi?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Progres akan hilang. Yakin keluar?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Lanjutkan',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _timer.cancel();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAudio(String audioFile) async {
    // Audio berbeda
    if (_currentAudioFile != audioFile) {
      await _audioPlayer.stop();

      _currentAudioFile = audioFile;
      _audioCompleted = false;

      setState(() {
        _isLoadingAudio = true;
      });

      try {
        await _audioPlayer.setSourceUrl(
          '${ApiService.mediaBaseUrl}/$audioFile',
        );

        await _audioPlayer.resume();

        setState(() {
          _isLoadingAudio = false;
        });
      } catch (e) {
        setState(() {
          _isLoadingAudio = false;
        });
      }

      return;
    }

    // Sedang play → pause
    if (_isPlaying) {
      await _audioPlayer.pause();

      setState(() {
        _isPlaying = false;
      });

      return;
    }

    // Audio selesai → putar dari awal
    if (_audioCompleted) {
      await _audioPlayer.seek(Duration.zero);

      await _audioPlayer.resume();

      _audioCompleted = false;

      return;
    }

    // Audio pause → lanjutkan
    await _audioPlayer.resume();
  }

  void _goToQuestion(int index) {
    setState(() {
      _currentIndex = index;
      _selectedAnswer = _userAnswers[index];
      _showQuestionList = false;
    });
    _audioPlayer.stop();
    _currentAudioFile = null;
    _audioCompleted = false;
    setState(() => _isPlaying = false);
  }

  void _openQuestionList(int total) {
    setState(() {
      _showQuestionList = !_showQuestionList;
    });

    if (_showQuestionList) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        const itemHeight = 50.0;
        const crossAxisCount = 8;

        final row = _currentIndex ~/ crossAxisCount;

        double offset = (row * itemHeight) - 120;

        if (offset < 0) {
          offset = 0;
        }

        _questionScrollController.jumpTo(offset);
      });
    }
  }

  void _goNext(List<LatihanSoalModel> soalList) {
    if (_currentIndex < soalList.length - 1) {
      final next = soalList[_currentIndex + 1];
      if (next.audioFile != _currentAudioFile) {
        _audioPlayer.stop();
        _currentAudioFile = null;
        _audioCompleted = false;
        setState(() => _isPlaying = false);
      }
      setState(() {
        _currentIndex++;
        _selectedAnswer = _userAnswers[_currentIndex];
      });
    }
  }

  void _goPrev(List<LatihanSoalModel> soalList) async {
    if (_currentIndex > 0) {
      final prev = soalList[_currentIndex - 1];

      if (prev.audioFile != _currentAudioFile) {
        await _audioPlayer.stop();

        _currentAudioFile = null;
        _audioCompleted = false;

        setState(() {
          _isPlaying = false;
        });
      }

      setState(() {
        _currentIndex--;
        _selectedAnswer = _userAnswers[_currentIndex];
      });
    }
  }

  void _selectAnswer(String answer) {
    setState(() {
      if (_selectedAnswer == answer) {
        _selectedAnswer = null;
        _userAnswers.remove(_currentIndex);
      } else {
        _selectedAnswer = answer;
        _userAnswers[_currentIndex] = answer;
      }
    });
  }

  bool _isListeningPart(int partId) => partId >= 1 && partId <= 4;
  String _getSectionTitle(int partId) {
    return partId <= 4 ? 'LISTENING SECTION' : 'READING SECTION';
  }

  bool _hasImagePart(int partId) => partId == 1;
  bool _hideOptionTextPart(int partId) => partId == 1 || partId == 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<List<LatihanSoalModel>>(
        future: _soalFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Memuat soal simulasi...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
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

          final soalList = snapshot.data!;
          if (soalList.isEmpty) {
            return const Center(child: Text('Soal simulasi tidak tersedia.'));
          }

          final soal = soalList[_currentIndex];
          final total = soalList.length;
          final partId = soal.partId;
          final answeredCount = _userAnswers.length;
          final progress = answeredCount / total;
          final options = <String>['A', 'B', 'C'];
          if (partId != 2 && soal.optionD.isNotEmpty) {
            options.add('D');
          }

          return SafeArea(
            child: Column(
              children: [
                // ── Top Bar ──────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _showExitDialog,
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
                      const SizedBox(width: 12),

                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _remainingSeconds < 300
                              ? Colors.red[50]
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: _remainingSeconds < 300
                                  ? Colors.red
                                  : const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _timerText,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _remainingSeconds < 300
                                    ? Colors.red
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),
                      Text(
                        'Question ${_currentIndex + 1} of $total',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Nomor Soal (collapsed) ────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _getSectionTitle(partId),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),

                          const Spacer(),

                          IconButton(
                            onPressed: () {
                              _openQuestionList(total);
                            },
                            icon: const Icon(
                              Icons.menu,
                              size: 28,
                              color: Color.fromARGB(255, 154, 153, 153),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Text(
                            '$answeredCount / $total Terjawab',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const Spacer(),

                          Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade300,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Nomor Soal (expanded/grid) ────────────
                if (_showQuestionList)
                  Container(
                    height: 220,
                    color: Colors.grey.shade50,
                    padding: const EdgeInsets.all(12),

                    child: GridView.builder(
                      controller: _questionScrollController,

                      itemCount: total,

                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),

                      itemBuilder: (context, index) {
                        return _buildNumberBubble(index, small: true);
                      },
                    ),
                  ),

                // ── Konten Soal ──────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gambar (Part 1)
                        if (_hasImagePart(partId) &&
                            soal.imageFile != null &&
                            soal.imageFile!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              '${ApiService.mediaBaseUrl}/${soal.imageFile}',
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) {
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

                        if (_hasImagePart(partId) &&
                            soal.imageFile != null &&
                            soal.imageFile!.isNotEmpty)
                          const SizedBox(height: 16),

                        // Audio (Part 1-4)
                        if (_isListeningPart(partId) &&
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

                        if (_isListeningPart(partId) &&
                            soal.audioFile != null &&
                            soal.audioFile!.isNotEmpty)
                          const SizedBox(height: 20),

                        // Teks soal (Part 3-7)
                        if (!_hideOptionTextPart(partId) &&
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

                        // Pilihan jawaban
                        ...options.map((key) {
                          final text = key == 'A'
                              ? soal.optionA
                              : key == 'B'
                              ? soal.optionB
                              : key == 'C'
                              ? soal.optionC
                              : soal.optionD;
                          final isSelected = _selectedAnswer == key;
                          final hideText = _hideOptionTextPart(partId);

                          return GestureDetector(
                            onTap: () => _selectAnswer(key),
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: hideText ? 12 : 16,
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
                                  if (!hideText) ...[
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
                          onPressed: _currentIndex > 0
                              ? () => _goPrev(soalList)
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),

                            backgroundColor: _currentIndex == 0
                                ? Colors.grey.shade200
                                : Colors.white,

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),

                            side: BorderSide(
                              color: _currentIndex == 0
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade400,
                            ),
                          ),
                          child: Text(
                            'Sebelumnya',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,

                              color: _currentIndex == 0
                                  ? Colors.grey
                                  : Colors.black87,
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
                              _showSubmitDialog();
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

  Widget _buildNumberBubble(int i, {bool small = false}) {
    final isAnswered = _userAnswers.containsKey(i);
    final isCurrent = i == _currentIndex;
    final size = small ? 42.0 : 44.0;
    final fontSize = small ? 13.0 : 14.0;

    return GestureDetector(
      onTap: () => _goToQuestion(i),
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.only(right: 6, bottom: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCurrent
              ? const Color(0xFF2563EB)
              : isAnswered
              ? Colors.blue[100]
              : Colors.white,
          border: Border.all(
            color: isCurrent ? const Color(0xFF2563EB) : Colors.grey[300]!,
          ),
        ),
        child: Center(
          child: Text(
            '${i + 1}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: isCurrent ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
