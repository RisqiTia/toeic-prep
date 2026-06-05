import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:toeic_prep/models/material_detail_model.dart';
import 'package:toeic_prep/services/api_service.dart';
import 'package:toeic_prep/widgets/header.dart';
import 'package:toeic_prep/services/api_service.dart';

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
  Map<String, String> _jawabanMulti = {};
  Map<String, String> _pembahasanMulti = {};

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
      final url = '${ApiService.mediaBaseUrl}/$audioFile';
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

  // ── CONTENT WITH MEDIA ──────────────────────────────────────

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
            '${ApiService.mediaBaseUrl}/${material.imageFile}',
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

  // ── FORMATTED CONTENT ───────────────────────────────────────

  Widget _buildFormattedContent(String text) {
    final lines = text.split('\n');
    final Map<String, List<String>> sections = {};
    final List<String> sectionOrder = [];
    String currentSection = '';
    List<String> buffer = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if ([
        'Apa yang diuji:',
        'Contoh Soal:',
        'Pembahasan:',
        'Strategi:',
        'Tips:',
      ].contains(trimmed)) {
        if (buffer.isNotEmpty || currentSection.isNotEmpty) {
          sections[currentSection] = List.from(buffer);
          if (!sectionOrder.contains(currentSection)) {
            sectionOrder.add(currentSection);
          }
        }
        buffer.clear();
        currentSection = trimmed;
      } else {
        buffer.add(line);
      }
    }
    if (buffer.isNotEmpty || currentSection.isNotEmpty) {
      sections[currentSection] = List.from(buffer);
      if (!sectionOrder.contains(currentSection)) {
        sectionOrder.add(currentSection);
      }
    }

    // Parse jawaban dulu sebelum render
    final pembahasanLines = sections['Pembahasan:'] ?? [];
    String jawabanBenar = '';
    _jawabanMulti = {};
    _pembahasanMulti = {};

    // Parse multi pembahasan dulu untuk isi _pembahasanMulti
    List<Map<String, dynamic>> pembahasanItems = [];
    Map<String, dynamic>? currentPembahasan;
    for (final line in pembahasanLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final multiMatch = RegExp(
        r'^Jawaban\s+(\d+):\s*(.+)$',
      ).firstMatch(trimmed);
      if (multiMatch != null) {
        if (currentPembahasan != null) pembahasanItems.add(currentPembahasan);
        currentPembahasan = {
          'number': multiMatch.group(1)!,
          'jawaban': multiMatch.group(2)!.trim(),
          'penjelasan': <String>[],
        };
      } else if (trimmed.startsWith('Jawaban:') &&
          !RegExp(r'^Jawaban\s+\d+:').hasMatch(trimmed)) {
        jawabanBenar = trimmed.replaceFirst('Jawaban:', '').trim();
      } else if (currentPembahasan != null) {
        (currentPembahasan['penjelasan'] as List<String>).add(trimmed);
      }
    }
    if (currentPembahasan != null) pembahasanItems.add(currentPembahasan);

    if (pembahasanItems.isNotEmpty) {
      _jawabanMulti = {
        for (final item in pembahasanItems)
          (item['number'] as String): (item['jawaban'] as String),
      };
      _pembahasanMulti = {
        for (final item in pembahasanItems)
          (item['number'] as String): (item['penjelasan'] as List<String>)
              .join('\n')
              .trim(),
      };
    }

    // Render
    final List<Widget> widgets = [];
    for (final section in sectionOrder) {
      final sectionLines = sections[section] ?? [];

      if (section == '') {
        for (final line in sectionLines) {
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
      } else if (section == 'Apa yang diuji:') {
        widgets.add(_buildApaYangDiujiCard(sectionLines));
      } else if (section == 'Contoh Soal:') {
        widgets.add(_buildContohSoalCard(sectionLines, jawabanBenar));
      } else if (section == 'Pembahasan:') {
        if (pembahasanItems.isEmpty) {
          widgets.add(_buildSinglePembahasanCard(sectionLines, jawabanBenar));
        }
        // Jika multi, pembahasan sudah ditampilkan per soal — skip
      } else if (section == 'Strategi:') {
        widgets.add(
          _buildPoinCard(sectionLines, 'Strategi:', isStrategi: true),
        );
      } else if (section == 'Tips:') {
        widgets.add(_buildPoinCard(sectionLines, 'Tips:', isStrategi: false));
      }

      widgets.add(const SizedBox(height: 12));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // ── CARD: APA YANG DIUJI ────────────────────────────────────

  Widget _buildApaYangDiujiCard(List<String> lines) {
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
          ...lines.map((line) => line.trim()).where((l) => l.isNotEmpty).map((
            line,
          ) {
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
          }),
        ],
      ),
    );
  }

  // ── CARD: CONTOH SOAL ───────────────────────────────────────

  Widget _buildContohSoalCard(List<String> lines, String jawabanBenar) {
    final isMultiQuestion = lines.any(
      (l) => RegExp(r'^Question\s+\d+:').hasMatch(l.trim()),
    );

    if (isMultiQuestion) {
      return _buildMultiQuestionCard(lines);
    }

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
          ..._buildChoices(choices, jawabanBenar),
        ],
      ),
    );
  }

  // ── MULTI QUESTION (Part 3 & 4) ─────────────────────────────

  Widget _buildMultiQuestionCard(List<String> lines) {
    List<String> percakapanLines = [];
    List<Map<String, dynamic>> questions = [];
    Map<String, dynamic>? currentQuestion;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final qMatch = RegExp(r'^(Question\s+\d+):$').firstMatch(trimmed);
      if (qMatch != null) {
        if (currentQuestion != null) questions.add(currentQuestion);
        currentQuestion = {
          'title': qMatch.group(1)!,
          'questionText': '',
          'choices': <Map<String, String>>[],
        };
        continue;
      }

      if (currentQuestion == null) {
        percakapanLines.add(trimmed);
      } else {
        final choiceMatch = RegExp(r'^([A-D])\.\s+(.+)$').firstMatch(trimmed);
        if (choiceMatch != null) {
          (currentQuestion['choices'] as List).add({
            'key': choiceMatch.group(1)!,
            'text': choiceMatch.group(2)!,
          });
        } else {
          final existing = currentQuestion['questionText'] as String;
          currentQuestion['questionText'] = existing.isEmpty
              ? trimmed
              : '$existing\n$trimmed';
        }
      }
    }
    if (currentQuestion != null) questions.add(currentQuestion);

    return Column(
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

        // Teks percakapan
        if (percakapanLines.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: percakapanLines
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

        // Tiap question + pembahasan langsung di bawahnya
        ...questions.map((q) {
          final qNumber =
              RegExp(r'\d+').firstMatch(q['title'] as String)?.group(0) ?? '';
          final jawabanBenar = _jawabanMulti[qNumber] ?? '';
          final penjelasan = _pembahasanMulti[qNumber] ?? '';
          final choices = (q['choices'] as List).cast<Map<String, String>>();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card soal
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${q['title']}:',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      q['questionText'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._buildChoices(choices, jawabanBenar),
                  ],
                ),
              ),

              // Pembahasan langsung di bawah soal
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 245, 200),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Pembahasan Question $qNumber (Jawaban: $jawabanBenar)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    if (penjelasan.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        penjelasan,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ── HELPER: BUILD CHOICES ───────────────────────────────────

  List<Widget> _buildChoices(
    List<Map<String, String>> choices,
    String jawabanBenar,
  ) {
    return choices.map((choice) {
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
                color: isBenar ? const Color(0xFF2563EB) : Colors.grey[200],
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
                  fontWeight: isBenar ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ── CARD: PEMBAHASAN SINGLE ─────────────────────────────────

  Widget _buildSinglePembahasanCard(List<String> lines, String jawabanBenar) {
    List<String> isi = [];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('Jawaban:')) continue;
      isi.add(trimmed);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 245, 200),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 Pembahasan (Jawaban: $jawabanBenar)',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          ...isi.map(
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
        ],
      ),
    );
  }

  // ── CARD: STRATEGI & TIPS ───────────────────────────────────

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
                if (isStrategi)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2563EB),
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
              Header(title: widget.partName),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
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
