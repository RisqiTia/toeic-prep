import 'package:flutter/material.dart';
import 'package:toeic_prep/widgets/header.dart';
import 'package:toeic_prep/services/api_service.dart';
import 'package:audioplayers/audioplayers.dart';

class PeriksaJawabanScreen extends StatefulWidget {
  final List soalList;
  final Map<int, String> userAnswers;
  final bool showQuestionList;
  final String? partName;
  final bool isPractice;

  const PeriksaJawabanScreen({
    super.key,
    required this.soalList,
    required this.userAnswers,
    this.showQuestionList = true,
    this.isPractice = false,
    this.partName,
  });

  @override
  State<PeriksaJawabanScreen> createState() => _PeriksaJawabanScreenState();
}

class _PeriksaJawabanScreenState extends State<PeriksaJawabanScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  bool _audioCompleted = false;
  String? _currentAudioFile;
  int currentIndex = 0;
  bool _showQuestionList = false;

  void _scrollToCurrentQuestion() {
    const itemHeight = 50.0;
    const crossAxisCount = 8;

    final row = currentIndex ~/ crossAxisCount;

    double offset = (row * itemHeight) - 120;

    if (offset < 0) {
      offset = 0;
    }

    _questionScrollController.jumpTo(offset);
  }

  final ScrollController _questionScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

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

  Future<void> _toggleAudio(String audioFile) async {
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

        debugPrint('Audio Error: $e');
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

      _audioCompleted = false;

      return;
    }

    await _audioPlayer.resume();

    setState(() {
      _isPlaying = true;
    });
  }

  void _stopAudio() {
    _audioPlayer.stop();

    _currentAudioFile = null;
    _audioCompleted = false;

    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final soal = widget.soalList[currentIndex];

    final userAnswer = widget.userAnswers[currentIndex];

    final correctAnswer = soal.correctAnswer;

    return Scaffold(
      body: Column(
        children: [
          const Header(title: 'Periksa Jawaban'),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Question ${currentIndex + 1} of ${widget.soalList.length}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 0),

                  if (widget.showQuestionList)
                    Padding(
                      padding: EdgeInsets.zero,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.isPractice
                                ? widget.partName!.toUpperCase()
                                : ((soal.partId <= 4)
                                      ? 'LISTENING SECTION'
                                      : 'READING SECTION'),
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          IconButton(
                            icon: const Icon(
                              Icons.menu,
                              size: 28,
                              color: Color.fromARGB(255, 154, 153, 153),
                            ),
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
                          ),
                        ],
                      ),
                    ),

                  if (widget.showQuestionList && _showQuestionList)
                    Container(
                      height: 200,
                      color: Colors.grey.shade50,
                      padding: const EdgeInsets.all(6),
                      child: GridView.builder(
                        controller: _questionScrollController,
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: widget.soalList.length,
                        itemBuilder: (context, index) {
                          final soal = widget.soalList[index];

                          final userAnswer = widget.userAnswers[index];

                          final bool isAnswered = userAnswer != null;

                          final bool isCorrect =
                              isAnswered && userAnswer == soal.correctAnswer;

                          final bool isCurrent = index == currentIndex;

                          return GestureDetector(
                            onTap: () {
                              _stopAudio();
                              setState(() {
                                currentIndex = index;
                                _showQuestionList = false;
                              });
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              margin: const EdgeInsets.only(
                                right: 6,
                                bottom: 4,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCurrent
                                    ? (!isAnswered
                                          ? Colors.grey.shade600
                                          : isCorrect
                                          ? const Color(0xFF2563EB)
                                          : Colors.red)
                                    : (!isAnswered
                                          ? Colors.grey.shade200
                                          : isCorrect
                                          ? Colors.blue.shade100
                                          : Colors.red.shade100),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent
                                        ? Colors.white
                                        : (!isAnswered
                                              ? Colors.grey.shade700
                                              : isCorrect
                                              ? const Color(0xFF2563EB)
                                              : Colors.red),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (soal.imageFile != null &&
                              soal.imageFile!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Image.network(
                                '${ApiService.mediaBaseUrl}/${soal.imageFile}',
                              ),
                            ),

                          if (soal.audioFile != null &&
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
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
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
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 20),

                          if (soal.questionText.isNotEmpty)
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

                          const SizedBox(height: 10),

                          _buildAnswerOption(
                            'A',
                            soal.optionA,
                            userAnswer,
                            correctAnswer,
                          ),

                          _buildAnswerOption(
                            'B',
                            soal.optionB,
                            userAnswer,
                            correctAnswer,
                          ),

                          _buildAnswerOption(
                            'C',
                            soal.optionC,
                            userAnswer,
                            correctAnswer,
                          ),

                          if (soal.optionD.isNotEmpty)
                            _buildAnswerOption(
                              'D',
                              soal.optionD,
                              userAnswer,
                              correctAnswer,
                            ),

                          const SizedBox(height: 20),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Penjelasan',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(soal.explanation),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: currentIndex > 0
                              ? () {
                                  _stopAudio();

                                  setState(() {
                                    currentIndex--;
                                  });
                                }
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),

                            backgroundColor: currentIndex == 0
                                ? Colors.grey.shade200
                                : Colors.white,

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),

                            side: BorderSide(
                              color: currentIndex == 0
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade400,
                            ),
                          ),
                          child: Text(
                            'Sebelumnya',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: currentIndex == 0
                                  ? Colors.grey
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),

                          onPressed: () {
                            // Soal belum berakhir
                            if (currentIndex < widget.soalList.length - 1) {
                              _stopAudio();

                              setState(() {
                                currentIndex++;
                              });
                            } else {
                              // Soal sudah berakhir, kembali ke halaman result
                              _stopAudio();
                              Navigator.pop(context);
                            }
                          },
                          child: Text(
                            currentIndex < widget.soalList.length - 1
                                ? 'Selanjutnya'
                                : 'Selesai',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerOption(
    String option,
    String text,
    String? userAnswer,
    String correctAnswer,
  ) {
    Color borderColor = Colors.grey.shade300;

    Color bgColor = Colors.white;

    if (option == correctAnswer) {
      borderColor = Colors.blue;
      bgColor = Colors.blue.shade50;
    } else if (option == userAnswer) {
      borderColor = Colors.red;
      bgColor = Colors.red.shade50;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: borderColor,
            child: Text(
              option,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
