import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:toeic_prep/models/material_detail_model.dart';
import 'package:toeic_prep/services/api_service.dart';
import 'package:toeic_prep/widgets/header.dart';

class MaterialDetailScreen extends StatefulWidget {
  final int partId;
  final String partName;

  const MaterialDetailScreen({
    super.key,
    required this.partId,
    required this.partName,
  });

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  late Future<MaterialDetail> _materialDetail;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoadingAudio = false;

  static const String _mediaBaseUrl = 'http://10.0.2.2/toeic_dataset_generator';

  @override
  void initState() {
    super.initState();
    _materialDetail = _fetchMaterialDetail();
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

  Future<MaterialDetail> _fetchMaterialDetail() async {
    final response = await ApiService.getMaterialsByPart(widget.partId);
    if (response['status'] == 'success') {
      final List data = response['data'];
      if (data.isEmpty) throw Exception('Materi tidak ditemukan');
      return MaterialDetail.fromJson(data[0]);
    } else {
      throw Exception(response['message'] ?? 'Gagal mengambil data materi');
    }
  }

  Future<void> _toggleAudio(String audioFile) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isLoadingAudio = true);
      final url = '$_mediaBaseUrl/$audioFile';
      try {
        await _audioPlayer.setSourceUrl(url);
        await _audioPlayer.resume();
        setState(() => _isLoadingAudio = false);
      } catch (e) {
        debugPrint('❌ Audio error: $e');
        setState(() => _isLoadingAudio = false);
      }
    }
  }

  // ── PARSE & BUILD KONTEN ────────────────────────────────────

  List<Widget> _buildContentWithMedia(MaterialDetail material) {
    final fullText = material.description;
    const contohSoalKeyword = 'Contoh Soal:';

    if (!fullText.contains(contohSoalKeyword)) {
      return [_buildFormattedContent(fullText)];
    }

    final parts = fullText.split(contohSoalKeyword);
    final textSebelum = parts[0].trim();
    final textSesudah = contohSoalKeyword + (parts.length > 1 ? parts[1] : '');

    return [
      if (textSebelum.isNotEmpty) _buildFormattedContent(textSebelum),
      if (textSebelum.isNotEmpty) const SizedBox(height: 12),

      // Gambar
      if (material.imageFile != null && material.imageFile!.isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            '$_mediaBaseUrl/${material.imageFile}',
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
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

      if (material.imageFile != null && material.imageFile!.isNotEmpty)
        const SizedBox(height: 12),

      // Audio player
      if (material.audioFile != null && material.audioFile!.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _toggleAudio(material.audioFile!),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2563EB),
                  ),
                  child: _isLoadingAudio
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Dengarkan Audio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),

      if (material.audioFile != null && material.audioFile!.isNotEmpty)
        const SizedBox(height: 12),

      if (textSesudah.isNotEmpty) _buildFormattedContent(textSesudah),
    ];
  }

  Widget _buildFormattedContent(String text) {
    final List<Widget> widgets = [];
    final lines = text.split('\n');

    String currentSection = '';
    List<String> sectionBuffer = [];

    // Cari jawaban benar dari teks Pembahasan dulu
    String jawabanBenar = '';
    bool inPembahasan = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == 'Pembahasan:') {
        inPembahasan = true;
        continue;
      }
      if (inPembahasan && trimmed.startsWith('Jawaban:')) {
        jawabanBenar = trimmed.replaceFirst('Jawaban:', '').trim();
        break;
      }
    }

    void flushBuffer() {
      if (sectionBuffer.isEmpty) return;

      if (currentSection == 'Apa yang diuji:') {
        widgets.add(_buildApaYangDiujiCard(sectionBuffer));
      } else if (currentSection == 'Contoh Soal:') {
        widgets.add(_buildContohSoalCard(sectionBuffer, jawabanBenar));
      } else if (currentSection == 'Pembahasan:') {
        widgets.add(_buildPembahasanCard(sectionBuffer));
      } else if (currentSection == 'Strategi:') {
        widgets.add(
          _buildPoinCard(sectionBuffer, 'Strategi:', isStrategi: true),
        );
      } else if (currentSection == 'Tips:') {
        widgets.add(_buildPoinCard(sectionBuffer, 'Tips:', isStrategi: false));
      } else {
        for (final line in sectionBuffer) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            widgets.add(
              Text(
                trimmed,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.8,
                ),
              ),
            );
            widgets.add(const SizedBox(height: 4));
          }
        }
      }
      sectionBuffer.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == 'Apa yang diuji:' ||
          trimmed == 'Contoh Soal:' ||
          trimmed == 'Pembahasan:' ||
          trimmed == 'Strategi:' ||
          trimmed == 'Tips:') {
        flushBuffer();
        currentSection = trimmed;
      } else {
        sectionBuffer.add(line);
      }
    }
    flushBuffer();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // ── CARD: CONTOH SOAL (dengan highlight jawaban benar) ──────

  Widget _buildContohSoalCard(List<String> lines, String jawabanBenar) {
    List<String> soalLines = [];
    List<Map<String, String>> choices = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final choiceMatch = RegExp(r'^([A-D])\.\s+(.+)$').firstMatch(trimmed);
      if (choiceMatch != null) {
        choices.add({
          'key': choiceMatch.group(1)!,
          'text': choiceMatch.group(2)!,
        });
      } else {
        soalLines.add(trimmed);
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contoh Soal:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),

          // Teks soal
          ...soalLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Pilihan A/B/C/D
          ...choices.map((choice) {
            final isBenar = choice['key'] == jawabanBenar;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isBenar ? Colors.blue[50] : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isBenar ? const Color(0xFF2563EB) : Colors.grey[300]!,
                  width: isBenar ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isBenar
                          ? const Color(0xFF2563EB)
                          : Colors.grey[200],
                    ),
                    child: Center(
                      child: Text(
                        choice['key']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isBenar ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      choice['text']!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: isBenar
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── CARD: STRATEGI & TIPS (abu, teks hitam normal) ──────────

  Widget _buildPoinCard(
    List<String> lines,
    String title, {
    required bool isStrategi,
  }) {
    final items = lines
        .map((l) => l.trim())
        .where((l) => l.startsWith('- '))
        .map((l) => l.substring(2).trim())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          String poinTitle = item;
          String poinDesc = '';
          if (item.contains(':')) {
            final splitIndex = item.indexOf(':');
            poinTitle = item.substring(0, splitIndex).trim();
            poinDesc = item.substring(splitIndex + 1).trim();
          }

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 225, 235, 244),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nomor bulat untuk strategi, garis abu untuk tips
                if (isStrategi)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2563EB),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red[500],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poinTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (poinDesc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          poinDesc,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildApaYangDiujiCard(List<String> lines) {
    final contentWidgets = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          if (line.startsWith('- ')) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  Expanded(
                    child: Text(
                      line.substring(2).trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.8,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.8,
              ),
            ),
          );
        })
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 225, 235, 244),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apa yang diuji:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          ...contentWidgets,
        ],
      ),
    );
  }

  Widget _buildPembahasanCard(List<String> lines) {
    final contentWidgets = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('Jawaban:'))
        .map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.8,
              ),
            ),
          ),
        )
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 177, 32),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pembahasan:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          ...contentWidgets,
        ],
      ),
    );
  }

  // ── BUILD ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<MaterialDetail>(
        future: _materialDetail,
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
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(
                      () => _materialDetail = _fetchMaterialDetail(),
                    ),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          final material = snapshot.data!;

          return Column(
            children: [
              // Header
              Header(title: widget.partName),

              // Konten scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Judul materi
                      Text(
                        material.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Konten dengan gambar & audio disisipkan
                      ..._buildContentWithMedia(material),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
