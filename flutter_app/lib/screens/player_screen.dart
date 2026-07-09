/// 播放器页面：边看边听 + 同步高亮 + 正式听书 App 风格
import "dart:async";
import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:provider/provider.dart";
import "../providers/book_provider.dart";
import "../models/book.dart";
import "../services/api_service.dart";

class PlayerScreen extends StatefulWidget {
  final int bookId;
  final bool startWithReadAlong;
  const PlayerScreen({super.key, required this.bookId, this.startWithReadAlong = false});

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
  bool _isReadAlong = false;
  bool _showTranscript = false;
  StreamSubscription? _posSub;
  String? _debugUrl;
  int _currentLineIndex = 0;
  double _transcriptFontSize = 16.0;
  Color _transcriptBgColor = const Color(0xFFF5F0EB);
  Color _transcriptTextColor = const Color(0xFF2D2D2D);
  double _transcriptLineHeight = 1.8;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _isReadAlong = widget.startWithReadAlong;
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
      } else if (rawUrl.startsWith("/")) {
        fullUrl = "${ApiService.baseUrl}$rawUrl";
      } else {
        fullUrl = "${ApiService.baseUrl}/$rawUrl";
      }
      setState(() => _debugUrl = fullUrl);
      await _player.setAudioSource(AudioSource.uri(Uri.parse(fullUrl)));
      _player.setSpeed(_speed);
      _posSub = _player.positionStream.listen((pos) {
        _updateCurrentLine(pos);
        _updateChapter(pos);
      });
      setState(() { _isReady = true; _loading = false; });
      _player.play();
    } catch (e) {
      setState(() {
        _error = "无法连接音频服务器 (${e.toString().substring(0, e.toString().length.clamp(0, 120))})";
        _loading = false;
      });
    }
  }

  void _updateChapter(Duration pos) {
    final bp = context.read<BookProvider>();
    final detail = bp.currentDetail;
    if (detail == null || detail.chapters.isEmpty) return;
    for (int i = 0; i < detail.chapters.length; i++) {
      if (pos.inSeconds >= detail.chapters[i].start.toInt() && pos.inSeconds < detail.chapters[i].end.toInt()) {
        if (_currentChapter != i) setState(() => _currentChapter = i);
        break;
      }
    }
  }

  void _updateCurrentLine(Duration pos) {
    final bp = context.read<BookProvider>();
    final detail = bp.currentDetail;
    if (detail == null || detail.transcript.isEmpty) return;
    final sec = pos.inMilliseconds / 1000.0;
    for (int i = 0; i < detail.transcript.length; i++) {
      final t = detail.transcript[i];
      if (sec >= t.start && sec < t.end) {
        if (_currentLineIndex != i) {
          setState(() => _currentLineIndex = i);
          _autoScroll(i);
        }
        return;
      }
    }
  }

  void _autoScroll(int index) {
    if (!_scrollCtrl.hasClients) return;
    final offset = index * (_transcriptFontSize * _transcriptLineHeight + 16) - 200;
    _scrollCtrl.animateTo(offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _seekToLine(int index) {
    final bp = context.read<BookProvider>();
    final detail = bp.currentDetail;
    if (detail == null || index >= detail.transcript.length) return;
    _player.seek(Duration(milliseconds: (detail.transcript[index].start * 1000).toInt()));
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return "${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}";
    return "${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}";
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookProvider>();
    final detail = bp.currentDetail;
    return Scaffold(
      backgroundColor: _isReadAlong ? _transcriptBgColor : null,
      appBar: AppBar(
        title: Text(detail?.title ?? "播放"),
        backgroundColor: _isReadAlong ? _transcriptBgColor : null,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isReadAlong ? Icons.headphones : Icons.menu_book),
            tooltip: _isReadAlong ? "只听书" : "边看边听",
            onPressed: () => setState(() => _isReadAlong = !_isReadAlong),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorBody(error: _error!, debugUrl: _debugUrl, bookId: widget.bookId)
              : _isReadAlong
                  ? _buildReadAlong(detail)
                  : _buildListenOnly(detail),
    );
  }

  Widget _buildModeTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white12 : Colors.black.withOpacity(0.05);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 60),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Expanded(child: _ModeBtn("智能朗读", _modeIndex == 0, () => setState(() => _modeIndex = 0))),
        Expanded(child: _ModeBtn("真人讲书", _modeIndex == 1, () => setState(() => _modeIndex = 1))),
      ]),
    );
  }

  int _modeIndex = 0;

  Widget _ModeBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(child: Text(label, style: TextStyle(color: selected ? Colors.white : null, fontSize: 13, fontWeight: FontWeight.w600))),
      ),
    );
  }

  Widget _buildListenOnly(BookDetail? detail) {
    return ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 40), children: [
      const SizedBox(height: 8),
      _buildModeTab(),
      const SizedBox(height: 24),
      Center(child: SizedBox(width: 220, height: 280, child: ClipRRect(borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 30, offset: const Offset(0, 8))],
          ),
          child: Center(child: Icon(Icons.book, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.4))),
        )))),
      const SizedBox(height: 20),
      Center(child: Text(detail?.title ?? "", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      if (detail?.author != null) Center(child: Text(detail!.author!, style: TextStyle(fontSize: 14, color: Colors.grey.shade600))),
      const SizedBox(height: 6),
      if (detail?.chapters.isNotEmpty == true) Center(child: Text(detail!.chapters[_currentChapter].title, style: TextStyle(fontSize: 13, color: Colors.grey.shade500))),
      const SizedBox(height: 24),
      StreamBuilder<Duration>(stream: _player.positionStream, builder: (ctx, posSnap) {
        final pos = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(stream: _player.durationStream, builder: (ctx, durSnap) {
          final dur = durSnap.data ?? Duration.zero;
          final max = (dur.inMilliseconds > 0) ? dur.inMilliseconds.toDouble() : 1.0;
          return Column(children: [
            Slider(value: pos.inMilliseconds.toDouble().clamp(0.0, max), min: 0, max: max,
              onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(_fmt(pos), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(_fmt(dur), style: const TextStyle(fontSize: 12, color: Colors.grey))])),
          ]);
        });
      }),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        IconButton(icon: const Icon(Icons.replay_10, size: 32), onPressed: () => _player.seek(_player.position - const Duration(seconds: 15))),
        StreamBuilder<PlayerState>(stream: _player.playerStateStream, builder: (ctx, snap) {
          final playing = snap.data?.playing ?? false;
          return Row(children: [
            IconButton(icon: const Icon(Icons.skip_previous, size: 32), onPressed: () => _skipChapter(-1)),
            IconButton(iconSize: 60, icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Theme.of(context).colorScheme.primary),
              onPressed: _isReady ? () => playing ? _player.pause() : _player.play() : null),
            IconButton(icon: const Icon(Icons.skip_next, size: 32), onPressed: () => _skipChapter(1)),
          ]);
        }),
        IconButton(icon: const Icon(Icons.forward_30, size: 32), onPressed: () => _player.seek(_player.position + const Duration(seconds: 15))),
      ]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _buildSpeedMenu(),
        const SizedBox(width: 24),
        _buildSleepTimer(),
        const SizedBox(width: 24),
        IconButton(icon: const Icon(Icons.download), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("下载已开始")))),
        const SizedBox(width: 24),
        IconButton(icon: const Icon(Icons.bookmark_border), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已加入书架")))),
      ]),
      if (detail?.chapters.isNotEmpty == true) ...[
        const SizedBox(height: 24),
        const Divider(),
        const Padding(padding: EdgeInsets.only(left: 16, top: 8), child: Text("章节", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ...detail!.chapters.asMap().entries.map((e) => ListTile(dense: true, selected: e.key == _currentChapter,
          leading: Text("#${e.value.index + 1}"), title: Text(e.value.title),
          subtitle: Text("${e.value.start.toStringAsFixed(1)}s"),
          onTap: () => _player.seek(Duration(milliseconds: (e.value.start * 1000).toInt())))),
      ],
    ]);
  }

  void _skipChapter(int dir) {
    final bp = context.read<BookProvider>();
    final detail = bp.currentDetail;
    if (detail == null || detail.chapters.isEmpty) return;
    int next = (_currentChapter + dir).clamp(0, detail.chapters.length - 1);
    _player.seek(Duration(milliseconds: (detail.chapters[next].start * 1000).toInt()));
  }

  Widget _buildSpeedMenu() {
    return PopupMenuButton<double>(
      initialValue: _speed,
      onSelected: (v) { setState(() => _speed = v); _player.setSpeed(v); },
      itemBuilder: (_) => [0.5, 0.8, 1.0, 1.2, 1.5, 2.0].map((v) => PopupMenuItem(value: v, child: Text("${v}x"))).toList(),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
        child: Text("${_speed}x", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    );
  }

  Widget _buildSleepTimer() {
    return PopupMenuButton<int>(
      onSelected: (v) {
        if (v <= 0) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${v} 分钟后自动停止")));
        Timer(Duration(minutes: v), () { if (_player.playing) _player.pause(); });
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 15, child: Text("15 分钟")),
        PopupMenuItem(value: 30, child: Text("30 分钟")),
        PopupMenuItem(value: 60, child: Text("60 分钟")),
        PopupMenuItem(value: 0, child: Text("关闭")),
      ],
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.timer, size: 18)),
    );
  }

  Widget _buildReadAlong(BookDetail? detail) {
    final lines = detail?.transcript ?? [];
    return Column(children: [
      // 顶部控制栏
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Expanded(child: Text(detail?.chapters.isNotEmpty == true ? detail!.chapters[_currentChapter].title : "", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          _buildSpeedMenu(),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == "font") _showFontSettings();
              if (v == "theme") _toggleTheme();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: "font", child: Text("字体设置")),
              PopupMenuItem(value: "theme", child: Text("切换主题")),
            ],
            icon: const Icon(Icons.settings, size: 20),
          ),
        ]),
      ),
      // 字幕区域
      Expanded(
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: lines.length,
          itemBuilder: (ctx, i) {
            final t = lines[i];
            final isActive = i == _currentLineIndex;
            return GestureDetector(
              onTap: () => _seekToLine(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isActive ? Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3)) : null,
                ),
                child: Text(t.text,
                  style: TextStyle(
                    fontSize: _transcriptFontSize,
                    color: isActive ? Theme.of(context).colorScheme.primary : _transcriptTextColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    height: _transcriptLineHeight,
                  )),
              ),
            );
          },
        ),
      ),
      // 底部播放控制
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        decoration: BoxDecoration(
          color: _transcriptBgColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: Column(children: [
          StreamBuilder<Duration>(stream: _player.positionStream, builder: (ctx, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            return StreamBuilder<Duration?>(stream: _player.durationStream, builder: (ctx, durSnap) {
              final dur = durSnap.data ?? Duration.zero;
              final max = (dur.inMilliseconds > 0) ? dur.inMilliseconds.toDouble() : 1.0;
              return Slider(value: pos.inMilliseconds.toDouble().clamp(0.0, max), min: 0, max: max,
                onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())));
            });
          }),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton(icon: const Icon(Icons.replay_10, size: 28), onPressed: () => _player.seek(_player.position - const Duration(seconds: 15))),
            StreamBuilder<PlayerState>(stream: _player.playerStateStream, builder: (ctx, snap) {
              final playing = snap.data?.playing ?? false;
              return IconButton(iconSize: 52, icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                onPressed: _isReady ? () => playing ? _player.pause() : _player.play() : null);
            }),
            IconButton(icon: const Icon(Icons.forward_30, size: 28), onPressed: () => _player.seek(_player.position + const Duration(seconds: 15))),
          ]),
        ]),
      ),
    ]);
  }

  void _showFontSettings() {
    showModalBottomSheet(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
      return Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("阅读设置", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [const Text("字体大小"), const Spacer(),
          IconButton(icon: const Icon(Icons.remove), onPressed: () => setSheetState(() { if (_transcriptFontSize > 12) { setState(() => _transcriptFontSize -= 2); } })),
          Text("${_transcriptFontSize.toInt()}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add), onPressed: () => setSheetState(() { if (_transcriptFontSize < 32) { setState(() => _transcriptFontSize += 2); } })),
        ]),
        const SizedBox(height: 12),
        Row(children: [const Text("行距"), const Spacer(),
          Text("${_transcriptLineHeight.toStringAsFixed(1)}x", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Slider(value: _transcriptLineHeight, min: 1.2, max: 3.0, divisions: 18,
            onChanged: (v) => setSheetState(() => setState(() => _transcriptLineHeight = v)), activeColor: Theme.of(context).colorScheme.primary),
        ]),
        const SizedBox(height: 12),
        Row(children: [const Text("背景"), const Spacer(),
          ...[const Color(0xFFF5F0EB), const Color(0xFF2D2D2D), const Color(0xFFEBEBEB), const Color(0xFFFFFFFF)].map((c) =>
            GestureDetector(onTap: () => setSheetState(() => setState(() { _transcriptBgColor = c; _transcriptTextColor = (c == const Color(0xFF2D2D2D)) ? Colors.white : const Color(0xFF2D2D2D); })),
              child: Container(margin: const EdgeInsets.only(left: 8), width: 36, height: 36,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _transcriptBgColor == c ? Colors.blue : Colors.grey.shade300, width: 2)),
              ))).toList(),
        ]),
        const SizedBox(height: 20),
      ]);
    }));
  }

  void _toggleTheme() {
    setState(() {
      if (_transcriptBgColor == const Color(0xFFF5F0EB)) {
        _transcriptBgColor = const Color(0xFF2D2D2D);
        _transcriptTextColor = Colors.white;
      } else {
        _transcriptBgColor = const Color(0xFFF5F0EB);
        _transcriptTextColor = const Color(0xFF2D2D2D);
      }
    });
  }
}

class _ErrorBody extends StatelessWidget {
  final String error;
  final String? debugUrl;
  final int bookId;
  const _ErrorBody({required this.error, this.debugUrl, required this.bookId});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off, size: 80, color: Colors.red),
      const SizedBox(height: 24),
      Text(error, style: const TextStyle(fontSize: 16, color: Colors.red), textAlign: TextAlign.center),
      if (debugUrl != null) ...[const SizedBox(height: 16), const Text("请求地址：", style: TextStyle(fontWeight: FontWeight.bold)),
        SelectableText(debugUrl!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16), const Text("提示：请检查后端地址是否配置正确", style: TextStyle(color: Colors.orange))],
      const SizedBox(height: 24),
      FilledButton.icon(icon: const Icon(Icons.refresh), label: const Text("重试"),
        onPressed: () => Navigator.pushReplacementNamed(context, "/player", arguments: bookId)),
    ])));
  }
}
