import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:toeic_prep/models/latihan_soal_model.dart';
import 'package:toeic_prep/services/user_session.dart';
import 'package:toeic_prep/services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _feedbackText = widget.motivation;
    _processResult();
  }

  Future<void> _processResult() async {
    final session = await UserSession.get();
    _currentLevel = session?['skill_level'] ?? 'beginner';

    if (widget.totalScore >= 700) {
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
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB),
                        height: 1,
                      ),
                    ),
                    Text(
                      'dari 900',
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

              // ── Card Listening & Reading ─────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildScoreCard(
                      icon: Icons.headphones_outlined,
                      iconColor: Colors.blue[400]!,
                      label: 'Listening',
                      score: widget.listeningScore,
                      maxScore: 500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildScoreCard(
                      icon: Icons.menu_book_outlined,
                      iconColor: Colors.teal[400]!,
                      label: 'Reading',
                      score: widget.readingScore,
                      maxScore: 400,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Feedback ─────────────────────────────────
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

              const SizedBox(height: 24),

              // ── Tombol Periksa Jawaban ───────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: ke halaman periksa jawaban
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

              // ── Tombol Uji Ulang (jika skor < 500) ──────
              if (widget.totalScore < 500)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigator.pushReplacement(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (_) => const SimulasiConfirmScreen(),
                      //   ),
                      // );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text(
                      'Uji Ulang',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              if (!_levelUp) const SizedBox(height: 12),

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

  Widget _buildScoreCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int score,
    required int maxScore,
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
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 4),
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
    );
  }
}
