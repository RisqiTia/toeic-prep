import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:toeic_prep/models/latihan_soal_model.dart';
import 'package:toeic_prep/services/user_session.dart';
import 'package:toeic_prep/screens/home/latihan/result_screen.dart';
import 'package:toeic_prep/services/api_service.dart';

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
  bool _audioCompleted = false;
  bool _isSubmitting = false; // ← loading saat submit

  int _currentIndex = 0;
  bool _showQuestionList = false;
  String? _selectedAnswer;
  final Map<int, String> _userAnswers = {};

  // attempt_id dari server saat fetch soal
  int? _attemptId;

  // Untuk Part 3 & 4 — track audio yang sedang aktif
  String? _currentAudioFile;
  final ScrollController _questionScrollController = ScrollController();

  bool get _isListening => widget.partId >= 1 && widget.partId <= 4;
  bool get _hasImage => widget.partId == 1;
  bool get _hideOptionText => widget.partId == 1 || widget.partId == 2;

  // ===================== MARKDOWN FORMATTER =====================

  List<InlineSpan> _parseFormattedText(String raw, TextStyle baseStyle) {
    final normalized = raw.replaceAll(r'\n', '\n');
    final lines = normalized.split('\n');

    final spans = <InlineSpan>[];
    final boldRegex = RegExp(r'\*\*(.+?)\*\*');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      final bulletMatch =
          RegExp(r'^\s*[\*\-]\s+(.*)$').firstMatch(line);

      if (bulletMatch != null) {
        line = bulletMatch.group(1) ?? '';
        spans.add(TextSpan(
          text: '• ',
          style: baseStyle,
        ));
      }

      int lastEnd = 0;

      for (final match in boldRegex.allMatches(line)) {
        if (match.start > lastEnd) {
          spans.add(
            TextSpan(
              text: line.substring(lastEnd, match.start),
              style: baseStyle,
            ),
          );
        }

        spans.add(
          TextSpan(
            text: match.group(1),
            style: baseStyle.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        );

        lastEnd = match.end;
      }

      if (lastEnd < line.length) {
        spans.add(
          TextSpan(
            text: line.substring(lastEnd),
            style: baseStyle,
          ),
        );
      }

      if (i != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  Widget _formattedText(String raw, TextStyle style) {
    final textStyle = Theme.of(context)
        .textTheme
        .bodyMedium!
        .merge(style);

    return RichText(
      text: TextSpan(
        style: textStyle,
        children: _parseFormattedText(raw, textStyle),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _soalFuture = _fetchSoal();
    _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return;

      setState(() {
        _isPlaying = false;
        _audioCompleted = true;
        _currentAudioFile = null;
        _isLoadingAudio = false;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;

      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Fetch Soal ──────────────────────────────────────────────────────────

  Future<List<LatihanSoalModel>> _fetchSoal() async {
    final session = await UserSession.get();
    final userId = session?['id'] ?? widget.userId;
    final skillLevel = session?['skill_level'] ?? 'beginner';

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.apiBaseUrl}/questions.php'
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
        groupKey = question.length > 200
            ? question.substring(0, 200)
            : question;
      }

      grouped.putIfAbsent(groupKey, () => []).add(soal);
    }

    final groupKeys = grouped.keys.toList()..shuffle();
    final result = <LatihanSoalModel>[];

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
        final soal = soalList[i];
        final userAnswer = _userAnswers[i] ?? '';
        final isCorrect = userAnswer == soal.correctAnswer;

        answers.add({
          'question_id': soal.id,
          'user_answer': userAnswer,
          'is_correct': isCorrect,
        });
      }

      final response = await http.post(
        Uri.parse('${ApiService.apiBaseUrl}/scores.php?action=save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'attempt_id': _attemptId, 'answers': answers}),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        // Hitung skor dari akurasi yang dikembalikan server
        final accuracy =
            (data['accuracy'] as num?)?.toInt() ?? _calculateScore(soalList);
        _goToResult(soalList, accuracy);
      } else {
        // Kalau server error, tetap tampilkan hasil lokal
        _goToResult(soalList, _calculateScore(soalList));
      }
    } catch (e) {
      debugPrint('Submit error: $e');
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
        builder: (_) => ResultScreen(
          score: score,
          soalList: soalList,
          userAnswers: _userAnswers,
          partName: widget.partName,
        ),
      ),
    );
  }

  // ─── Hitung Skor Lokal ────────────────────────────────────────

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
      _audioCompleted = false;
      setState(() {
        _isPlaying = false;
        _isLoadingAudio = true;
      });
      try {
        await _audioPlayer.setSourceUrl(
          '${ApiService.mediaBaseUrl}/$audioFile',
        );
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

      setState(() {
        _isPlaying = false;
      });

      return;
    }

    if (_audioCompleted) {
      await _audioPlayer.seek(Duration.zero);

      await _audioPlayer.resume();

      setState(() {
        _audioCompleted = false;
        _isPlaying = true;
      });

      return;
    }

    await _audioPlayer.resume();

    setState(() {
      _isPlaying = true;
    });
  }

  // ─── Navigasi Soal ───────────────────────────────────────────────────────

  void _goNext(List<LatihanSoalModel> soalList) {
    if (_currentIndex < soalList.length - 1) {
      final nextSoal = soalList[_currentIndex + 1];
      if (nextSoal.audioFile != _currentAudioFile) {
        _audioPlayer.stop();
        _currentAudioFile = null;
        _audioCompleted = false;
        setState(() {
          _isPlaying = false;
        });
      }
      setState(() {
        _currentIndex++;
        _selectedAnswer = _userAnswers[_currentIndex];
      });
    }
  }

  void _goPrev(List<LatihanSoalModel> soalList) {
    if (_currentIndex > 0) {
      final prevSoal = soalList[_currentIndex - 1];

      // Berhenti jika audio berbeda
      if (prevSoal.audioFile != _currentAudioFile) {
        _audioPlayer.stop();

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

  void _scrollToCurrentQuestion() {
    const double itemHeight = 50;

    final row = _currentIndex ~/ 8;

    _questionScrollController.animateTo(
      row * itemHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluar Latihan?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Progres latihan akan hilang. Yakin keluar?'),
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
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSubmitDialog(List<LatihanSoalModel> soalList) {
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
                'SELESAIKAN LATIHAN',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              const Text(
                'Kamu bisa menyelesaikan latihan sekarang atau memeriksa kembali jawabanmu sebelum dikirim.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Cek Kembali',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _submitAnswers(soalList);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                      ),
                      child: const Text(
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

          final currentAudio = soal.audioFile;

          final jumlahSoalAudio = soalList
              .where((s) => s.audioFile == currentAudio)
              .length;

          return SafeArea(
            child: Column(
              children: [
                // ── Top Bar ────────────────────────────────────────────────
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
                          child: const Icon(Icons.close),
                        ),
                      ),

                      const Spacer(),

                      Text(
                        'Question ${_currentIndex + 1} of $total',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.partName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),

                          const Spacer(),

                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showQuestionList = !_showQuestionList;
                              });

                              if (_showQuestionList) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _scrollToCurrentQuestion();
                                });
                              }
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
                            '${_userAnswers.length} / $total Terjawab',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),

                          const Spacer(),

                          Text(
                            '${((_userAnswers.length / total) * 100).round()}%',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _userAnswers.length / total,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade300,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_showQuestionList)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    color: Colors.grey.shade50,
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      controller: _questionScrollController,
                      shrinkWrap: true,
                      itemCount: soalList.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                      itemBuilder: (context, index) {
                        final isAnswered = _userAnswers.containsKey(index);

                        final isCurrent = index == _currentIndex;

                        return GestureDetector(
                          onTap: () async {
                            final targetSoal = soalList[index];

                            // Berhenti saat audio beda
                            if (targetSoal.audioFile != _currentAudioFile) {
                              _audioPlayer.stop();

                              _currentAudioFile = null;
                              _audioCompleted = false;

                              setState(() {
                                _isPlaying = false;
                              });
                            }

                            setState(() {
                              _currentIndex = index;
                              _selectedAnswer = _userAnswers[index];
                              _showQuestionList = false;
                            });
                          },

                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCurrent
                                  ? const Color(0xFF2563EB)
                                  : isAnswered
                                  ? Colors.blue.shade100
                                  : Colors.grey.shade200,
                              border: Border.all(
                                color: isCurrent
                                    ? const Color(0xFF2563EB)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
                              '${ApiService.mediaBaseUrl}/${soal.imageFile}',
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
                        if ((widget.partId == 3 || widget.partId == 4) &&
                            soal.audioFile != null &&
                            soal.audioFile!.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.record_voice_over,
                                  color: Colors.blue,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Audio ini digunakan untuk menjawab $jumlahSoalAudio pertanyaan yang saling terkait.',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),

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

                        // ── TEKS SOAL (Part 3-7)
                        if (!_hideOptionText && soal.questionText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _formattedText(
                              soal.questionText,
                              const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                height: 1.6,
                              ),
                            ),
                          ),

                        // ── PILIHAN JAWABAN
                        ...(widget.partId == 2
                                ? ['A', 'B', 'C']
                                : ['A', 'B', 'C', 'D'])
                            .map((key) {
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
                                          child: _formattedText(
                                            text,
                                            const TextStyle(
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
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  if (_currentIndex < soalList.length - 1) {
                                    _goNext(soalList);
                                  } else {
                                    // Soal terakhir → submit ke server
                                    _showSubmitDialog(soalList);
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
