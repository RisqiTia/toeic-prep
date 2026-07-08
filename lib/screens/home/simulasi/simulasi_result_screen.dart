import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:toeic_prep/models/latihan_soal_model.dart';
import 'package:toeic_prep/screens/home/simulasi/periksa_jawaban_screen.dart';
import 'package:toeic_prep/services/user_session.dart';
import 'package:toeic_prep/services/api_service.dart';
import 'package:toeic_prep/screens/home/rekomendasi_latihan_screen.dart';

// ─── Enum section yang perlu rekomendasi ────────────────────────────────────
enum WeakSection { listening, reading, keduanya }

// ─── Screen ──────────────────────────────────────────────────────────────────
class SimulasiResultScreen extends StatefulWidget {
  final int totalScore;
  final int listeningScore;
  final int readingScore;
  final int userId;
  final List<LatihanSoalModel> soalList;
  final Map<int, String> userAnswers;
  final String motivation;

  const SimulasiResultScreen({
    super.key,
    required this.totalScore,
    required this.listeningScore,
    required this.readingScore,
    required this.userId,
    required this.soalList,
    required this.userAnswers,
    required this.motivation,
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

  // Rekomendasi — section mana yang lemah
  WeakSection? _weakSection;
  String _rekomendasiPesan = '';

  // Threshold skor untuk rekomendasi
  static const int _threshold = 275;
  // Total soal rekomendasi
  static const int _totalSoalRekomendasi = 30;

  @override
  void initState() {
    super.initState();
    _feedbackText = widget.motivation;
    _buildRekomendasi();
    _processResult();
  }

  /// Tentukan section mana yang di bawah threshold (≤ 275)
  void _buildRekomendasi() {
    final listeningLemah = widget.listeningScore <= _threshold;
    final readingLemah = widget.readingScore <= _threshold;

    if (listeningLemah && readingLemah) {
      _weakSection = WeakSection.keduanya;
      _rekomendasiPesan =
          'Skor Listening dan Reading kamu masih di bawah 275. '
          'Kerjakan rekomendasi latihan untuk meningkatkan kemampuanmu.';
    } else if (listeningLemah) {
      _weakSection = WeakSection.listening;
      _rekomendasiPesan =
          'Skor Listening kamu masih di bawah 275. '
          'Kerjakan rekomendasi latihan untuk meningkatkan kemampuanmu.';
    } else if (readingLemah) {
      _weakSection = WeakSection.reading;
      _rekomendasiPesan =
          'Skor Reading kamu masih di bawah 275. '
          'Kerjakan rekomendasi latihan untuk meningkatkan kemampuanmu.';
    } else {
      _weakSection = null;
      _rekomendasiPesan = '';
    }
  }

  Future<void> _processResult() async {
    final session = await UserSession.get();
    _currentLevel = session?['skill_level'] ?? 'beginner';

    // Naik level jika skor >= 550
    if (widget.totalScore >= 550) {
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
          weakSection: _weakSection!,
          totalSoal: _totalSoalRekomendasi,
        ),
      ),
    );
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
    final bool butuhRekomendasi = _weakSection != null;

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

                    // Badge level
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

              // ── Card Listening & Reading (berdampingan) ──
              Row(
                children: [
                  Expanded(
                    child: _buildScoreCard(
                      icon: Icons.headphones_outlined,
                      iconColor: Colors.blue[400]!,
                      label: 'Listening',
                      score: widget.listeningScore,
                      maxScore: 495,
                      isWeak: widget.listeningScore <= _threshold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildScoreCard(
                      icon: Icons.menu_book_outlined,
                      iconColor: Colors.teal[400]!,
                      label: 'Reading',
                      score: widget.readingScore,
                      maxScore: 495,
                      isWeak: widget.readingScore <= _threshold,
                    ),
                  ),
                ],
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

  /// Card skor simpel — hanya ikon, label, dan angka skor
  Widget _buildScoreCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int score,
    required int maxScore,
    required bool isWeak,
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
        // Border merah tipis jika skor di bawah threshold
        border: isWeak
            ? Border.all(color: Colors.red[200]!, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (isWeak) ...[
                const Spacer(),
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange[400], size: 16),
              ],
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$score',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isWeak ? Colors.red[400] : Colors.black87,
                  ),
                ),
                TextSpan(
                  text: '/$maxScore',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}