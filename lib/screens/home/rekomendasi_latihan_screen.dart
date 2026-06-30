import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:toeic_prep/models/latihan_soal_model.dart';
import 'package:toeic_prep/services/api_service.dart';
import 'package:toeic_prep/screens/home/simulasi/simulasi_result_screen.dart'
    show WeakPartInfo;
import 'package:toeic_prep/screens/home/hasil_latihan_screen.dart';

/// Layar mengerjakan soal rekomendasi latihan.
/// Soal diambil dari recommendation.php (tidak disimpan ke DB).
class RekomendasiLatihanScreen extends StatefulWidget {
  final int userId;
  final List<WeakPartInfo> weakParts; // part-part yang direkomendasikan
  final Map<int, int> soalPerPartMap; // jumlah soal per part_id (total 30)
  final int percobaan; // percobaan ke-berapa (1-based, diteruskan ke hasil)

  const RekomendasiLatihanScreen({
    super.key,
    required this.userId,
    required this.weakParts,
    required this.soalPerPartMap,
    this.percobaan = 1,
  });

  @override
  State<RekomendasiLatihanScreen> createState() =>
      _RekomendasiLatihanScreenState();
}

class _RekomendasiLatihanScreenState extends State<RekomendasiLatihanScreen> {
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
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _soalFuture = _fetchSoal();

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _audioCompleted = true;
      });
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
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Fetch soal rekomendasi dari recommendation.php ──────────────────────

  Future<List<LatihanSoalModel>> _fetchSoal() async {
    final partIds = widget.weakParts.map((p) => p.partId).join(',');

    // Bangun parameter limits: "3:15,4:15" dari soalPerPartMap
    final limitsParam = widget.soalPerPartMap.entries
        .map((e) => '${e.key}:${e.value}')
        .join(',');

    final url = Uri.parse(
      '${ApiService.apiBaseUrl}/recommendation.php'
      '?action=get_questions'
      '&user_id=${widget.userId}'
      '&part_ids=$partIds'
      '&limits=$limitsParam',
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        final List parts = data['parts'] as List;
        final List<LatihanSoalModel> allSoal = [];

        for (final part in parts) {
          final List questions = part['questions'] as List;
          allSoal.addAll(questions.map((e) => LatihanSoalModel.fromJson(e)));
        }
        return allSoal;
      } else {
        throw Exception(data['message'] ?? 'Gagal mengambil soal rekomendasi');
      }
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  // ─── Submit jawaban (hitung lokal, tidak ke DB) ───────────────────────────

  void _submit(List<LatihanSoalModel> soalList) {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    int benar = 0;
    for (int i = 0; i < soalList.length; i++) {
      if ((_userAnswers[i] ?? '') == soalList[i].correctAnswer) benar++;
    }

    // Skor dalam persen (0–100)
    final int skorPersen = soalList.isNotEmpty
        ? ((benar / soalList.length) * 100).round()
        : 0;

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HasilLatihanScreen(
          skorPersen: skorPersen,
          totalSoal: soalList.length,
          benar: benar,
          userId: widget.userId,
          weakParts: widget.weakParts,
          soalPerPartMap: widget.soalPerPartMap,
          percobaan: widget.percobaan,
        ),
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
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Apakah kamu sudah yakin dengan jawabanmu?',
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
                        side: BorderSide(color: Colors.grey[300]!),
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
                              _submit(soalList);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
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

  // ─── Audio ───────────────────────────────────────────────────────────────

  Future<void> _toggleAudio(String audioFile) async {
    if (_currentAudioFile != audioFile) {
      await _audioPlayer.stop();
      _currentAudioFile = audioFile;
      _audioCompleted = false;
      setState(() => _isLoadingAudio = true);
      try {
        await _audioPlayer.setSourceUrl(
          '${ApiService.mediaBaseUrl}/$audioFile',
        );
        await _audioPlayer.resume();
        setState(() => _isLoadingAudio = false);
      } catch (_) {
        setState(() => _isLoadingAudio = false);
      }
      return;
    }
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
      return;
    }
    if (_audioCompleted) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.resume();
      _audioCompleted = false;
      return;
    }
    await _audioPlayer.resume();
  }

  // ─── Navigasi soal ────────────────────────────────────────────────────────

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

  void _goPrev() {
    if (_currentIndex > 0) {
      _audioPlayer.stop();
      _currentAudioFile = null;
      _audioCompleted = false;
      setState(() {
        _isPlaying = false;
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
  bool _hasImagePart(int partId) => partId == 1;
  bool _hideOptionTextPart(int partId) => partId == 1 || partId == 2;

  String _getPartLabel(int partId) {
    switch (partId) {
      case 1:
        return 'Photographs';
      case 2:
        return 'Question-Response';
      case 3:
        return 'Conversations';
      case 4:
        return 'Talks';
      case 5:
        return 'Incomplete Sentences';
      case 6:
        return 'Text Completion';
      case 7:
        return 'Reading Comprehension';
      default:
        return 'Part $partId';
    }
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Memuat soal latihan...',
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
            return const Center(
              child: Text('Soal rekomendasi tidak tersedia.'),
            );
          }

          final soal = soalList[_currentIndex];
          final total = soalList.length;
          final partId = soal.partId;
          final answeredCount = _userAnswers.length;
          final progress = answeredCount / total;

          final options = ['A', 'B', 'C'];
          if (partId != 2 && soal.optionD.isNotEmpty) options.add('D');

          return SafeArea(
            child: Column(
              children: [
                // ── AppBar sederhana ─────────────────────
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
                        onTap: () => _showExitDialog(context),
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
                      const Text(
                        'Rekomendasi Latihan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentIndex + 1} / $total',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Progress & nomor soal ─────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Part ${soal.partId} — ${_getPartLabel(soal.partId)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => setState(
                              () => _showQuestionList = !_showQuestionList,
                            ),
                            icon: Icon(
                              Icons.menu,
                              size: 24,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '$answeredCount / $total Terjawab',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: Colors.grey.shade300,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Grid nomor soal (collapsed) ───────────
                if (_showQuestionList)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    color: Colors.grey[50],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                            childAspectRatio: 1,
                          ),
                      itemCount: total,
                      itemBuilder: (context, i) => _buildNumberBubble(i),
                    ),
                  ),

                // ── Konten soal ───────────────────────────
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
                            ),
                          ),

                        if (_hasImagePart(partId) &&
                            soal.imageFile != null &&
                            soal.imageFile!.isNotEmpty)
                          const SizedBox(height: 16),

                        // Audio player (Part 1-4)
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

                // ── Tombol navigasi bawah ─────────────────
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
                          onPressed: _currentIndex > 0 ? _goPrev : null,
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

  Widget _buildNumberBubble(int i) {
    final isAnswered = _userAnswers.containsKey(i);
    final isCurrent = i == _currentIndex;

    return GestureDetector(
      onTap: () => _goToQuestion(i),
      child: Container(
        margin: const EdgeInsets.only(right: 4, bottom: 4),
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
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isCurrent ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluar Latihan?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Progres akan hilang. Yakin keluar?'),
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
}