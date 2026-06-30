import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:toeic_prep/models/latihan_soal_model.dart';
import 'package:toeic_prep/screens/home/simulasi/periksa_jawaban_screen.dart';
import 'package:toeic_prep/services/user_session.dart';
import 'package:toeic_prep/services/api_service.dart';
import 'package:toeic_prep/screens/home/rekomendasi_latihan_screen.dart';

// ─── Model sederhana untuk info part yang lemah ─────────────────────────────
class WeakPartInfo {
  final int partId;
  final String partName;
  final String partType;
  final double accuracy;

  const WeakPartInfo({
    required this.partId,
    required this.partName,
    required this.partType,
    required this.accuracy,
  });

  factory WeakPartInfo.fromJson(Map<String, dynamic> json) => WeakPartInfo(
    partId: json['part_id'] as int,
    partName: json['part_name'] as String,
    partType: json['part_type'] as String,
    accuracy: (json['accuracy'] as num).toDouble(),
  );
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class SimulasiResultScreen extends StatefulWidget {
  final int totalScore;
  final int listeningScore;
  final int readingScore;
  final int userId;
  final List<LatihanSoalModel> soalList;
  final Map<int, String> userAnswers;
  final String motivation;

  /// Daftar semua part diurutkan dari yang paling lemah (dari backend)
  final List<WeakPartInfo> weakParts;

  const SimulasiResultScreen({
    super.key,
    required this.totalScore,
    required this.listeningScore,
    required this.readingScore,
    required this.userId,
    required this.soalList,
    required this.userAnswers,
    required this.motivation,
    required this.weakParts,
  });

  @override
  State<SimulasiResultScreen> createState() => _SimulasiResultScreenState();
}

class _SimulasiResultScreenState extends State<SimulasiResultScreen> {
  String _feedbackText = '';
  String _currentLevel = '';
  String _newLevel = '';
  bool _levelUp = false;
  bool _isUpdating = true;

  // Part yang direkomendasikan (accuracy < 60%)
  late List<WeakPartInfo> _recommendedParts;

  // Distribusi jumlah soal per part (total 30)
  late Map<int, int> _soalPerPartMap;

  // Pesan rekomendasi
  String _rekomendasiPesan = '';

  // Pisahkan weakParts per section untuk ditampilkan di card
  late List<WeakPartInfo> _listeningParts; // part 1-4
  late List<WeakPartInfo> _readingParts;   // part 5-7

  @override
  void initState() {
    super.initState();
    _feedbackText = widget.motivation;
    _separatePartsBySection();
    _buildRekomendasi();
    _processResult();
  }

  /// Pisahkan weakParts menjadi listening (1-4) dan reading (5-7)
  void _separatePartsBySection() {
    _listeningParts = widget.weakParts
        .where((p) => p.partId >= 1 && p.partId <= 4)
        .toList();
    _readingParts = widget.weakParts
        .where((p) => p.partId >= 5 && p.partId <= 7)
        .toList();
  }

  /// Tentukan part mana saja yang direkomendasikan (accuracy < 60%)
  /// dan distribusikan 30 soal secara proporsional ke part paling lemah
  void _buildRekomendasi() {
    const double threshold = 60.0;
    const int totalSoal = 30;

    // Filter hanya part dengan accuracy < 60%
    final weakList = widget.weakParts
        .where((p) => p.accuracy < threshold)
        .toList();

    if (weakList.isEmpty) {
      _recommendedParts = [];
      _soalPerPartMap = {};
      _rekomendasiPesan = '';
      return;
    }

    _recommendedParts = weakList;

    // Distribusi soal: part paling lemah dapat lebih banyak soal
    // Gunakan "inverse accuracy" sebagai bobot
    // Semakin rendah accuracy, semakin besar bobot
    final Map<int, double> bobotMap = {};
    double totalBobot = 0;
    for (final p in weakList) {
      // Bobot = (100 - accuracy), min 1
      final bobot = (100.0 - p.accuracy).clamp(1.0, 100.0);
      bobotMap[p.partId] = bobot;
      totalBobot += bobot;
    }

    // Hitung jumlah soal per part (floor dulu, sisanya ke part terlemah)
    _soalPerPartMap = {};
    int sisaSoal = totalSoal;
    final sortedByAccuracy = List<WeakPartInfo>.from(weakList)
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    for (int i = 0; i < sortedByAccuracy.length; i++) {
      final p = sortedByAccuracy[i];
      if (i == sortedByAccuracy.length - 1) {
        // Part terakhir (terlemah) dapat sisa soal
        _soalPerPartMap[p.partId] = sisaSoal;
      } else {
        final porsi = ((bobotMap[p.partId]! / totalBobot) * totalSoal).floor();
        final jumlah = porsi.clamp(1, sisaSoal - (sortedByAccuracy.length - 1 - i));
        _soalPerPartMap[p.partId] = jumlah;
        sisaSoal -= jumlah;
      }
    }

    // Buat pesan rekomendasi
    final namaPartList = weakList.map((p) => p.partName).toList();
    String namaGabung;
    if (namaPartList.length == 1) {
      namaGabung = namaPartList.first;
    } else {
      final semuaKecualiTerakhir = namaPartList.sublist(0, namaPartList.length - 1);
      namaGabung = '${semuaKecualiTerakhir.join(', ')} dan ${namaPartList.last}';
    }

    _rekomendasiPesan =
        'Persentase benar Anda pada $namaGabung masih di bawah 60%, silahkan kerjakan rekomendasi latihan.';
  }

  Future<void> _processResult() async {
    final session = await UserSession.get();
    _currentLevel = session?['skill_level'] ?? 'beginner';

    // Naik level jika skor >= 500
    if (widget.totalScore >= 500) {
      _newLevel = _getNextLevel(_currentLevel);
      _levelUp = _newLevel != _currentLevel;
      if (_levelUp) await _updateLevel(_newLevel, session);
    } else {
      _newLevel = _currentLevel;
      _levelUp = false;
    }

    if (mounted) setState(() => _isUpdating = false);
  }

  String _getNextLevel(String current) {
    if (current == 'beginner') return 'intermediate';
    if (current == 'intermediate') return 'advanced';
    return 'advanced';
  }

  Future<void> _updateLevel(
    String newLevel,
    Map<String, dynamic>? session,
  ) async {
    final email = session?['email'] ?? '';
    try {
      await http.post(
        Uri.parse('${ApiService.apiBaseUrl}/auth.php?action=update_skill'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'skill_level': newLevel}),
      );
      await UserSession.save(
        id: session?['id'] ?? 0,
        name: session?['name'] ?? '',
        email: email,
        skillLevel: newLevel,
        rememberMe: session?['remember_me'] ?? false,
      );
    } catch (e) {
      debugPrint('Update level error: $e');
    }
  }

  String _getLevelLabel(String level) {
    switch (level) {
      case 'beginner':
        return 'Pemula';
      case 'intermediate':
        return 'Menengah';
      case 'advanced':
        return 'Mahir';
      default:
        return level;
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'beginner':
        return Colors.orange;
      case 'intermediate':
        return Colors.blue;
      case 'advanced':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _goToRekomendasi() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RekomendasiLatihanScreen(
          userId: widget.userId,
          weakParts: _recommendedParts,
          soalPerPartMap: _soalPerPartMap,
        ),
      ),
    );
  }

  /// Warna indikator akurasi per part
  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 80) return Colors.green[600]!;
    if (accuracy >= 60) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  @override
  Widget build(BuildContext context) {
    if (_isUpdating) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Menghitung hasil...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final displayLevel = _levelUp ? _newLevel : _currentLevel;
    final bool butuhRekomendasi = _recommendedParts.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Card Skor Total ──────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'SKOR TOTAL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.totalScore}',
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                        height: 1,
                      ),
                    ),
                    Text(
                      'dari 990',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 12),

                    // Badge level (naik atau tetap)
                    _levelUp
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getLevelColor(displayLevel),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _getLevelColor(
                                    displayLevel,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.arrow_circle_up,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getLevelLabel(displayLevel),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getLevelColor(displayLevel),
                              ),
                            ),
                            child: Text(
                              _getLevelLabel(displayLevel),
                              style: TextStyle(
                                color: _getLevelColor(displayLevel),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Card Listening ───────────────────────────
              _buildScoreCardWithParts(
                icon: Icons.headphones_outlined,
                iconColor: Colors.blue[400]!,
                label: 'Listening',
                score: widget.listeningScore,
                maxScore: 495,
                partList: _listeningParts,
              ),

              const SizedBox(height: 12),

              // ── Card Reading ─────────────────────────────
              _buildScoreCardWithParts(
                icon: Icons.menu_book_outlined,
                iconColor: Colors.teal[400]!,
                label: 'Reading',
                score: widget.readingScore,
                maxScore: 495,
                partList: _readingParts,
              ),

              const SizedBox(height: 12),

              // ── Feedback motivasi ─────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _feedbackText,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // ── Pesan rekomendasi ─────────────────────────
              if (butuhRekomendasi) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA500),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _rekomendasiPesan,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Tombol Periksa Jawaban ───────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PeriksaJawabanScreen(
                          soalList: widget.soalList,
                          userAnswers: widget.userAnswers,
                          showQuestionList: true,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Periksa jawaban',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Tombol Rekomendasi Latihan ────────────────
              if (butuhRekomendasi)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _goToRekomendasi,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text(
                      'Rekomendasi latihan',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // ── Kembali ke Beranda ───────────────────────
              TextButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: Text(
                  'Kembali ke Beranda',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Card Listening/Reading dengan breakdown persentase per part di bawahnya
  Widget _buildScoreCardWithParts({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int score,
    required int maxScore,
    required List<WeakPartInfo> partList,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris atas: ikon + label + skor
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const Spacer(),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$score',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    TextSpan(
                      text: '/$maxScore',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Breakdown per part (jika ada data)
          if (partList.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ...partList.map((p) => _buildPartAccuracyRow(p)),
          ],
        ],
      ),
    );
  }

  /// Baris persentase benar per part dengan progress bar mini
  Widget _buildPartAccuracyRow(WeakPartInfo p) {
    final accuracyInt = p.accuracy.round();
    final color = _getAccuracyColor(p.accuracy);
    final isWeak = p.accuracy < 60;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Nama part
              Expanded(
                child: Row(
                  children: [
                    Text(
                      p.partName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isWeak) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          'Lemah',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Persentase
              Text(
                '$accuracyInt%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Progress bar mini
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.accuracy / 100,
              minHeight: 5,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}