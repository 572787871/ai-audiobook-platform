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

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}" : "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
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

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookProvider>();
    final detail = bp.currentDetail;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _showTranscript ? _bgColor : null,
      appBar: AppBar(
        backgroundColor: _showTranscript ? _bgColor : null,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { _player.stop(); Navigator.pop(context); }),
        title: Text(detail?.title ?? "播放", style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(_showTranscript ? Icons.headphones : Icons.auto_stories),
            onPressed: () => setState(() => _showTranscript = !_showTranscript),
            tooltip: _showTranscript ? "只听书" : "边看边听"),
          PopupMenuButton<String>(itemBuilder: (_) => [
            const PopupMenuItem(value: "download", child: ListTile(leading: Icon(Icons.download), title: Text("下载"), contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: "timer", child: ListTile(leading: Icon(Icons.timer), title: Text("定时关闭"), contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: "share", child: ListTile(leading: Icon(Icons.share), title: Text("分享"), contentPadding: EdgeInsets.zero)),
          ]),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.wifi_off, size: 64, color: Colors.red),
                    const SizedBox(height: 16), Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    if (_debugUrl != null) ...[const SizedBox(height: 8), SelectableText(_debugUrl!, style: const TextStyle(fontSize: 11, color: Colors.grey))],
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => Navigator.pushReplacementNamed(context, "/player", arguments: widget.bookId), child: const Text("重试")),
                  ])))
              : _showTranscript ? _buildReadAlong(detail!) : _buildPlayerUI(detail!),
    );
  }

  Widget _buildPlayerUI(BookDetail detail) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      const Spacer(flex: 1),
      Container(margin: const EdgeInsets.symmetric(horizontal: 60), padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Expanded(child: _ModeButton(label: "智能朗读", selected: _modeIndex == 0, onTap: () => setState(() => _modeIndex = 0))),
          Expanded(child: _ModeButton(label: "真人讲书", selected: _modeIndex == 1, onTap: () => setState(() => _modeIndex = 1))),
        ])),
      const Spacer(flex: 1),
      Container(width: 240, height: 280,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: AppTheme.primary.withOpacity(0.12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))]),
        child: Center(child: Icon(Icons.book, size: 80, color: AppTheme.primary.withOpacity(0.3)))),
      const Spacer(flex: 1),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(detail.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textPrimary))),
      if (detail.author != null) ...[const SizedBox(height: 4), Text(detail.author!, style: TextStyle(color: Colors.grey.shade600, fontSize: 14))],
      const SizedBox(height: 24),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: StreamBuilder<Duration>(
        stream: _player.positionStream, builder: (ctx, posSnap) => StreamBuilder<Duration?>(
          stream: _player.durationStream, builder: (ctx, durSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final dur = durSnap.data ?? const Duration(seconds: 1);
            return Column(children: [
              SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: AppTheme.primary, inactiveTrackColor: isDark ? Colors.white24 : Colors.black12,
                thumbColor: AppTheme.primary),
                child: Slider(value: pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()),
                  min: 0, max: dur.inMilliseconds.toDouble().clamp(1, double.infinity),
                  onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_fmt(pos), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(_fmt(dur), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
            ]);
          }),
      )),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.replay_10, size: 32), onPressed: () => _player.seek(_player.position - const Duration(seconds: 10))),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.skip_previous, size: 36), onPressed: () {
          if (_currentChapter > 0 && detail.chapters.isNotEmpty) {
            _player.seek(Duration(seconds: detail.chapters[_currentChapter - 1].start.toInt()));
            setState(() => _currentChapter--);
          }
        }),
        const SizedBox(width: 8),
        StreamBuilder<PlayerState>(stream: _player.playerStateStream, builder: (ctx, snap) {
          final playing = snap.data?.playing ?? false;
          return GestureDetector(
            onTap: _isReady ? () => playing ? _player.pause() : _player.play() : null,
            child: Container(width: 72, height: 72,
              decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))]),
              child: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36)));
        }),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.skip_next, size: 36), onPressed: () {
          if (_currentChapter < detail.chapters.length - 1) {
            _player.seek(Duration(seconds: detail.chapters[_currentChapter + 1].start.toInt()));
            setState(() => _currentChapter++);
          }
        }),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.forward_30, size: 32), onPressed: () => _player.seek(_player.position + const Duration(seconds: 30))),
      ]),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ...[0.8, 1.0, 1.2, 1.5, 2.0].map((s) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(label: Text("${s}x", style: TextStyle(fontSize: 13, color: _speed == s ? Colors.white : null)),
            selected: _speed == s, selectedColor: AppTheme.primary,
            onSelected: (v) { setState(() => _speed = s); _player.setSpeed(s); }))),
      ]),
      const Spacer(flex: 2),
    ]);
  }

  Widget _buildReadAlong(BookDetail detail) {
    return Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: _bgColor,
        child: Row(children: [
          IconButton(icon: const Icon(Icons.text_fields, size: 20), onPressed: _showReadSettings),
          Expanded(child: StreamBuilder<Duration>(
            stream: _player.positionStream, builder: (ctx, snap) {
              final pos = snap.data ?? Duration.zero;
              final dur = _player.duration ?? const Duration(seconds: 1);
              return SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                activeTrackColor: AppTheme.primary, inactiveTrackColor: Colors.grey.shade300),
                child: Slider(value: pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()),
                  min: 0, max: dur.inMilliseconds.toDouble(), onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt()))));
            })),
          StreamBuilder<PlayerState>(stream: _player.playerStateStream, builder: (ctx, snap) {
            return IconButton(icon: Icon(snap.data?.playing == true ? Icons.pause : Icons.play_arrow, size: 24),
              onPressed: () { snap.data?.playing == true ? _player.pause() : _player.play(); }); }),
        ])),
      Expanded(child: Container(color: _bgColor,
        child: ListView.builder(controller: _scrollCtrl, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: detail.transcript.length, itemBuilder: (ctx, i) {
            final line = detail.transcript[i];
            final isActive = i == _currentLineIndex;
            return GestureDetector(
              onTap: () { _player.seek(Duration(milliseconds: (line.start * 1000).toInt())); setState(() => _currentLineIndex = i); },
              child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: _lineSpacing * 2, horizontal: 8),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(color: isActive ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isActive ? Border.all(color: AppTheme.primary.withOpacity(0.3)) : null),
                child: Text(line.text, style: TextStyle(fontSize: _fontSize, height: _lineSpacing,
                  color: isActive ? AppTheme.primary : (_isDarkReading ? Colors.white70 : Colors.black87),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal))));
          }))),
    ]);
  }

  void _showReadSettings() {
    showModalBottomSheet(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("阅读设置", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          Row(children: [
            const Text("字体大小"), const Spacer(),
            IconButton(icon: const Icon(Icons.remove), onPressed: () { if (_fontSize > 12) { setState(() => _fontSize -= 2); setSheetState(() {}); } }),
            Text("${_fontSize.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add), onPressed: () { if (_fontSize < 28) { setState(() => _fontSize += 2); setSheetState(() {}); } }),
          ]),
          Row(children: [
            const Text("行距"), const Spacer(),
            IconButton(icon: const Icon(Icons.remove), onPressed: () { if (_lineSpacing > 1.2) { setState(() => _lineSpacing -= 0.2); setSheetState(() {}); } }),
            Text("${_lineSpacing.toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add), onPressed: () { if (_lineSpacing < 2.4) { setState(() => _lineSpacing += 0.2); setSheetState(() {}); } }),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            const Text("背景"), const Spacer(),
            ...[const Color(0xFFF5F0E8), const Color(0xFFE8F0F5), const Color(0xFFF0F5E8), const Color(0xFFFFFFF0), const Color(0xFF2D2D2D)]
              .map((c) => GestureDetector(
                onTap: () { setState(() { _bgColor = c; _isDarkReading = c == const Color(0xFF2D2D2D); }); setSheetState(() {}); },
                child: Container(width: 36, height: 36, margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _bgColor == c ? AppTheme.primary : Colors.grey.shade300, width: 2))))),
          ]),
          const SizedBox(height: 20),
        ])),
    );
  }
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
