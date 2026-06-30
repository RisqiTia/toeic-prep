import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:toeic_prep/screens/home/simulasi/simulasi_result_screen.dart'
    show WeakPartInfo;
import 'package:toeic_prep/screens/home/rekomendasi_latihan_screen.dart';

class HasilLatihanScreen extends StatefulWidget {
  final int skorPersen;
  final int totalSoal;
  final int benar;
  final int userId;
  final List<WeakPartInfo> weakParts;
  final Map<int, int> soalPerPartMap;
  final int percobaan;

  const HasilLatihanScreen({
    super.key,
    required this.skorPersen,
    required this.totalSoal,
    required this.benar,
    required this.userId,
    required this.weakParts,
    required this.soalPerPartMap,
    this.percobaan = 1,
  });

  @override
  State<HasilLatihanScreen> createState() => _HasilLatihanScreenState();
}

class _HasilLatihanScreenState extends State<HasilLatihanScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnim;

  late AnimationController _overlayController;
  late Animation<double> _overlayFade;
  late Animation<double> _overlayScale;

  bool _showOverlay = false;

  static const int _threshold = 65;
  static const int _maxPercobaan = 3;
  static const int _delaySebelumPopup = 5; // detik

  @override
  void initState() {
    super.initState();

    // Animasi lingkaran skor
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnim = Tween<double>(
      begin: 0,
      end: widget.skorPersen / 100,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    // Animasi overlay pop-up
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _overlayFade = CurvedAnimation(
      parent: _overlayController,
      curve: Curves.easeIn,
    );
    _overlayScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _overlayController, curve: Curves.easeOutBack),
    );

    // Jika percobaan ke-3 dan belum lulus → tampilkan overlay setelah delay
    if (widget.percobaan >= _maxPercobaan && widget.skorPersen < _threshold) {
      Future.delayed(const Duration(seconds: _delaySebelumPopup), () {
        if (mounted) {
          setState(() => _showOverlay = true);
          _overlayController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _overlayController.dispose();
    super.dispose();
  }

  bool get _lulus => widget.skorPersen >= _threshold;
  bool get _sudahMaksPercobaan => widget.percobaan >= _maxPercobaan && !_lulus;

  void _cobaUjiUlang() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _kerjakanLagi() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RekomendasiLatihanScreen(
          userId: widget.userId,
          weakParts: widget.weakParts,
          soalPerPartMap: widget.soalPerPartMap,
          percobaan: widget.percobaan + 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'HASIL LATIHAN',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Halaman utama skor (selalu terlihat) ──────────────────────────
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Lingkaran skor animasi
                      AnimatedBuilder(
                        animation: _progressAnim,
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size(220, 220),
                            painter: _ScoreRingPainter(
                              progress: _progressAnim.value,
                              activeColor: const Color(0xFF2563EB),
                            ),
                            child: SizedBox(
                              width: 220,
                              height: 220,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '👑',
                                    style: TextStyle(fontSize: 36),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${widget.skorPersen}',
                                    style: const TextStyle(
                                      fontSize: 56,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'SKOR ANDA',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      Text(
                        '${widget.benar} dari ${widget.totalSoal} soal benar',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),

                      // Badge percobaan (hanya jika belum maks)
                      if (!_lulus && !_sudahMaksPercobaan) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Percobaan ${widget.percobaan} dari $_maxPercobaan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      // Teks menunggu pop-up (percobaan ke-3, sebelum overlay muncul)
                      if (_sudahMaksPercobaan && !_showOverlay) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Percobaan $_maxPercobaan dari $_maxPercobaan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[400],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Tombol bawah — disembunyikan jika percobaan ke-3 & belum lulus
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    if (!_sudahMaksPercobaan)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _lulus ? _cobaUjiUlang : _kerjakanLagi,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _lulus ? 'Coba uji ulang' : 'Kerjakan lagi',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () =>
                          Navigator.popUntil(context, (route) => route.isFirst),
                      child: Text(
                        'Kembali ke Beranda',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Overlay pop-up peringatan (3x gagal) — melayang di atas ────────
          if (_showOverlay)
            FadeTransition(
              opacity: _overlayFade,
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: ScaleTransition(
                    scale: _overlayScale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ikon
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.sentiment_dissatisfied_rounded,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Perlu Belajar Lebih Lagi!',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Kamu telah mencoba latihan sebanyak ${widget.percobaan} kali '
                            'namun belum mencapai skor 65%. '
                            'Yuk, pelajari kembali materi dan latihan soal terlebih dahulu '
                            'sebelum mencoba simulasi lagi.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.popUntil(
                                context,
                                (route) => route.isFirst,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Kembali ke Beranda',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Custom Painter lingkaran skor ───────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color activeColor;

  const _ScoreRingPainter({required this.progress, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 14;
    const strokeWidth = 18.0;

    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}