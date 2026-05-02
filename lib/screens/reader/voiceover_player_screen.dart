import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceoverPlayerScreen extends StatefulWidget {
  final String title;
  final String audioUrl;

  const VoiceoverPlayerScreen({
    super.key,
    required this.title,
    required this.audioUrl,
  });

  @override
  State<VoiceoverPlayerScreen> createState() => _VoiceoverPlayerScreenState();
}

class _VoiceoverPlayerScreenState extends State<VoiceoverPlayerScreen> {
  final mainBlue = const Color(0xFF0D2144);
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
          _isLoading = false;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    try {
      await _audioPlayer.setSource(UrlSource(widget.audioUrl));
      // Auto play
      await _audioPlayer.resume();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading audio: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Listen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: mainBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: mainBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.headphones, size: 64, color: mainBlue),
              ),
              const SizedBox(height: 32),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: mainBlue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Voiceover playing",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 48),
              
              if (_isLoading)
                CircularProgressIndicator(color: mainBlue)
              else
                Column(
                  children: [
                    Builder(
                      builder: (context) {
                        double maxVal = _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0;
                        double currentVal = _position.inSeconds.toDouble().clamp(0.0, maxVal);
                        return Slider(
                          activeColor: mainBlue,
                          inactiveColor: Colors.grey.shade300,
                          min: 0,
                          max: maxVal,
                          value: currentVal,
                          onChanged: (value) async {
                            final position = Duration(seconds: value.toInt());
                            await _audioPlayer.seek(position);
                          },
                        );
                      }
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(_position), style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text(_formatDuration(_duration), style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 42,
                          color: mainBlue,
                          icon: const Icon(Icons.replay_10),
                          onPressed: () async {
                            final newPosition = _position - const Duration(seconds: 10);
                            await _audioPlayer.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
                          },
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: mainBlue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: mainBlue.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: IconButton(
                            iconSize: 48,
                            color: Colors.white,
                            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: () async {
                              if (_isPlaying) {
                                await _audioPlayer.pause();
                              } else {
                                await _audioPlayer.resume();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          iconSize: 42,
                          color: mainBlue,
                          icon: const Icon(Icons.forward_10),
                          onPressed: () async {
                            final newPosition = _position + const Duration(seconds: 10);
                            await _audioPlayer.seek(newPosition > _duration ? _duration : newPosition);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
