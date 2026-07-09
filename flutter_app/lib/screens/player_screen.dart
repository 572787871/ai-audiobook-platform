/// 播放器 - 专业听书 App 风格 + 边看边听模式
import "dart:async";
import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:provider/provider.dart";
import "../providers/book_provider.dart";
import "../models/book.dart";
import "../services/api_service.dart";
import "../theme/app_theme.dart";

class PlayerScreen extends StatefulWidget {
  final int bookId;
  const PlayerScreen({super.key, required this.bookId});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isReady = false;
  bool _loading = true;
  String? _error;
  double _speed = 1.0;
  int _currentChapter = 0;
  bool _showTranscript = false;
  int _modeIndex = 0; // 0=智能朗读 1=真人讲书
  String? _debugUrl;
  StreamSubscription? _posSub;
  final ScrollController _scrollCtrl = ScrollController();
  int _currentLineIndex = 0;
  double _fontSize = 16;
  Color _bgColor = const Color(0xFFF5F0E8);
  double _lineSpacing = 1.6;
  bool _isDarkReading = false;

  static const List<double> _speedOptions = [0.8, 1.0, 1.2, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final bp = context.read<BookProvider>();
      await bp.loadDetail(widget.bookId);
      final detail = bp.currentDetail;
      if (detail == null) { setState(() { _error = "加载有声书信息失败"; _loading = false; }); return; }
      if (detail.audioUrl == null || detail.audioUrl!.isEmpty) {
        setState(() { _error = "音频尚未生成，请等待 TTS 任务完成"; _loading = false; }); return;
      }
      String rawUrl = detail.audioUrl!;
      String fullUrl;
      if (rawUrl.startsWith("http://") || rawUrl.startsWith("https://")) {
        fullUrl = rawUrl;
      } else {
        fullUrl = rawUrl.startsWith("/") ? "${ApiService.baseUrl}$rawUrl" : "${ApiService.baseUrl}/$rawUrl";
      }
      setState(() => _debugUrl = fullUrl);
      await _player.setAudioSource(AudioSource.uri(Uri.parse(fullUrl)));
      _posSub = _player.positionStream.listen((pos) {
        if (!mounted) return;
        final d = bp.currentDetail;
        if (d == null) return;
        for (int i = 0; i < d.chapters.length; i++) {
          final c = d.chapters[i];
          if (pos.inSeconds >= c.start.toInt() && pos.inSeconds < c.end.toInt()) {
            if (_currentChapter != i) setState(() => _currentChapter = i);
            break;
          }
        }
        // 高亮当前字幕行
        if (d.transcript.isNotEmpty) {
          for (int i = 0; i < d.transcript.length; i++) {
            final t = d.transcript[i];
            if (pos.inMilliseconds / 1000 >= t.start && pos.inMilliseconds / 1000 <= t.end) {
              if (_currentLineIndex != i) {
                setState(() => _currentLineIndex = i);
                _autoScroll(i);
              }
              break;
            }
          }
        }
      });
      setState(() { _isReady = true; _loading = false; });
      _player.play();
    } catch (e) {
      setState(() { _error = "无法连接音频服务器 (${e.toString().substring(0, e.toString().length.clamp(0, 120))})"; _loading = false; });
    }
  }

  void _autoScroll(int index) {
    if (_scrollCtrl.hasClients && index * 60 > _scrollCtrl.position.pixels + 200) {
      _scrollCtrl.animateTo(index * 60.0 - 100, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(color: selected ? Colors.white : Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
