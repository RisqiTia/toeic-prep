import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:toeic_prep/services/user_session.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class RiwayatItem {
  final int id;
  final String type; // 'simulasi' | 'latihan'
  final String title;
  final String date;
  final int score;
  final String scoreLabel; // 'Skor' | 'Akurasi'
  final String partName;
  final int? listeningScore;
  final int? readingScore;
  final String? scoreCategory;

  RiwayatItem({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.score,
    required this.scoreLabel,
    required this.partName,
    this.listeningScore,
    this.readingScore,
    this.scoreCategory,
  });

  factory RiwayatItem.fromJson(Map<String, dynamic> json) {
    return RiwayatItem(
      id:             json['id'] ?? 0,
      type:           json['type'] ?? 'latihan',
      title:          json['title'] ?? '',
      date:           json['date'] ?? '',
      score:          (json['score'] as num?)?.toInt() ?? 0,
      scoreLabel:     json['score_label'] ?? 'Skor',
      partName:       json['part_name'] ?? '',
      listeningScore: (json['listening_score'] as num?)?.toInt(),
      readingScore:   (json['reading_score'] as num?)?.toInt(),
      scoreCategory:  json['score_category'],
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  static const String _apiBaseUrl =
      'http://10.0.2.2/toeic_prep_app/toeic_api';

  String _activeFilter = 'Semua';
  List<RiwayatItem> _allRiwayat = [];
  int _lastSimulasiScore = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRiwayat();
  }

  Future<void> _fetchRiwayat() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await UserSession.get();
      final userId = session?['id'] ?? 0;

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/riwayat.php?user_id=$userId'),
      );

      // CEK STATUS RESPONSE
      if (response.statusCode != 200) {
        throw Exception('Server error (${response.statusCode})');
      }

      // CEK BODY KOSONG
      if (response.body.isEmpty) {
        setState(() {
          _allRiwayat = [];
          _lastSimulasiScore = 0;
          _isLoading = false;
        });
        return;
      }

      final data = jsonDecode(response.body);

      // JIKA SUCCESS
      if (data['status'] == 'success') {
        final List rawList = data['data'] ?? [];

        final items = rawList
            .map((e) => RiwayatItem.fromJson(e))
            .toList();

        setState(() {
          _allRiwayat = items;
          _lastSimulasiScore =
              (data['last_simulasi_score'] as num?)?.toInt() ?? 0;
          _isLoading = false;
        });
      }

      // JIKA DATA KOSONG
      else if (data['status'] == 'empty') {
        setState(() {
          _allRiwayat = [];
          _lastSimulasiScore = 0;
          _isLoading = false;
        });
      }

      // ERROR LAIN
      else {
        throw Exception(data['message'] ?? 'Gagal mengambil riwayat');
      }
    } catch (e) {
      setState(() {
        // JANGAN ERROR PAGE
        // tetap tampilkan halaman kosong
        _allRiwayat = [];
        _lastSimulasiScore = 0;
        _isLoading = false;
        _error = null;
      });

      debugPrint('Riwayat Error: $e');
    }
  }

  List<RiwayatItem> get _filteredRiwayat {
    if (_activeFilter == 'Simulasi') {
      return _allRiwayat.where((e) => e.type == 'simulasi').toList();
    } else if (_activeFilter == 'Latihan') {
      return _allRiwayat.where((e) => e.type == 'latihan').toList();
    }
    return _allRiwayat;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Center(
                child: Text(
                  'Riwayat',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _fetchRiwayat,
                          child: ListView(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              // ── Card Skor Simulasi Terakhir ────────────
                              _buildScoreCard(),
                              const SizedBox(height: 20),

                              // ── Filter Chips ───────────────────────────
                              _buildFilterRow(),
                              const SizedBox(height: 16),

                              // ── List Riwayat ───────────────────────────
                              if (_filteredRiwayat.isEmpty)
                                _buildEmpty()
                              else
                                ..._filteredRiwayat
                                    .map((item) => _buildRiwayatCard(item)),

                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skor Simulasi Terakhir',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _lastSimulasiScore == 0 ? '-' : _lastSimulasiScore.toString(),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1,
                ),
              ),
              if (_lastSimulasiScore > 0) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '/ 900',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_lastSimulasiScore == 0)
            Text(
              'Belum ada simulasi',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final filters = ['Semua', 'Simulasi', 'Latihan'];
    return Row(
      children: filters.map((f) {
        final isActive = _activeFilter == f;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => setState(() => _activeFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF2563EB)
                      : Colors.grey[300]!,
                ),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRiwayatCard(RiwayatItem item) {
    final isSimulasi = item.type == 'simulasi';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Ikon ────────────────────────────────────────────────────────
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSimulasi
                  ? const Color(0xFF2563EB)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSimulasi
                  ? Icons.timer_outlined
                  : Icons.edit_note_rounded,
              color: isSimulasi ? Colors.white : Colors.grey[600],
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // ── Judul & Tanggal ───────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.date,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // ── Skor / Akurasi ────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isSimulasi
                    ? item.score.toString()
                    : '${item.score}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                item.scoreLabel,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat riwayat.\n${_error ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchRiwayat,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Coba Lagi',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Belum ada riwayat'
              '${_activeFilter == 'Semua' ? '' : ' $_activeFilter'}',
              style:
                  TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}