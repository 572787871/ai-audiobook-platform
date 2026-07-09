import "dart:async";
import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:provider/provider.dart";
import "../providers/book_provider.dart";
import "../models/book.dart";
import "../services/api_service.dart";

class PlayerScreen extends StatefulWidget {
  final int bookId;
  const PlayerScreen({super.key, required this.bookId});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  bool _isReady = false;
  bool _loading = true;
  String? _error;
  double _speed = 1.0;
  int _currentChapter = 0;
  String _playMode = "listen"; // listen | read
  StreamSubscription? _posSub;
  String? _debugUrl;
  int _currentLine = 0;
  ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _posSub?.cancel();
    _player.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _player.pause();
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
      _posSub = _player.positionStream.listen((pos) {
        final d = detail;
        if (d == null) return;
        for (int i = 0; i < d.chapters.length; i++) {
          final c = d.chapters[i];
          if (pos.inSeconds >= c.start.toInt() && pos.inSeconds < c.end.toInt()) {
            if (_currentChapter != i) setState(() => _currentChapter = i);
            break;
          }
        }
        // 找当前字幕行
        for (int i = 0; i < d.transcript.length; i++) {
          final t = d.transcript[i];
          if (pos.inSeconds >= t.start.toInt() && pos.inSeconds < t.end.toInt()) {
            if (_currentLine != i) {
              setState(() => _currentLine = i);
              _autoScroll(i);
            }
            break;
          }
        }
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

  void _autoScroll(int idx) {
    if (!_scrollCtrl.hasClients) return;
    final pos = idx * 72.0;
    if (pos > _scrollCtrl.position.maxScrollExtent - 200 || pos < _scrollCtrl.position.pixels) {
      _scrollCtrl.animateTo(pos.clamp(0, _scrollCtrl.position.maxScrollExtent), duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}' : '${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bp = context.watch<BookProvider>();
    final detail = bp.currentDetail;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(detail?.title ?? "播放", style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isReady) PopupMenuButton<String>(
            onSelected: (v) {
              if (v == "timer") _showTimerPicker(context);
              if (v == "speed") _showSpeedPicker(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: "timer", child: ListTile(leading: Icon(Icons.timer), title: Text("定时关闭"), dense: true)),
              PopupMenuItem(value: "speed", child: ListTile(leading: Icon(Icons.speed), title: Text("倍速"), dense: true)),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.wifi_off, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  if (_debugUrl != null) ...[
                    const SizedBox(height: 8), Text("URL: $_debugUrl", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(onPressed: () => Navigator.pushReplacementNamed(context, "/player", arguments: widget.bookId), child: const Text("重试")),
                ]))
              : Column(children: [
                  Expanded(child: _playMode == "read" && detail != null && detail.transcript.isNotEmpty
                      ? _ReadMode(detail: detail, currentLine: _currentLine, scrollCtrl: _scrollCtrl, player: _player)
                      : _PlayerArt(detail: detail, cs: cs)),
                  _PlayerControls(player: _player, isReady: _isReady, speed: _speed, currentChapter: _currentChapter,
                      detail: detail, fmt: _fmt, cs: cs, playMode: _playMode,
                      onPlayModeToggle: () => setState(() => _playMode = _playMode == "listen" ? "read" : "listen"),
                      onSpeedChange: (v) { setState(() => _speed = v); _player.setSpeed(v); },
                      onSeek: (p) => _player.seek(Duration(seconds: p.toInt())),
                      onPrevChapter: () => _seekToChapter(_currentChapter - 1, detail),
                      onNextChapter: () => _seekToChapter(_currentChapter + 1, detail),
                  ),
                ]),
    );
  }

  void _seekToChapter(int idx, BookDetail? d) {
    if (d == null || idx < 0 || idx >= d.chapters.length) return;
    setState(() => _currentChapter = idx);
    _player.seek(Duration(seconds: d.chapters[idx].start.toInt()));
  }

  void _showTimerPicker(BuildContext ctx) {
    showModalBottomSheet(context: ctx, builder: (bctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: const Text("15 分钟后"), onTap: () { _player.stop(); Navigator.pop(bctx); }),
      ListTile(title: const Text("30 分钟后"), onTap: () { _player.stop(); Navigator.pop(bctx); }),
      ListTile(title: const Text("60 分钟后"), onTap: () { _player.stop(); Navigator.pop(bctx); }),
      ListTile(title: const Text("当前章节结束"), onTap: () { _player.stop(); Navigator.pop(bctx); }),
    ]));
  }

  void _showSpeedPicker(BuildContext ctx) {
    showModalBottomSheet(context: ctx, builder: (bctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      for (final s in [0.8, 1.0, 1.2, 1.5, 2.0])
        ListTile(title: Text("${s}x"), trailing: s == _speed ? const Icon(Icons.check) : null,
            onTap: () { Navigator.pop(bctx); _player.setSpeed(s); setState(() => _speed = s); }),
    ]));
  }
}

class _PlayerArt extends StatelessWidget {
  final BookDetail? detail;
  final ColorScheme cs;
  const _PlayerArt({required this.detail, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: cs.primaryContainer.withValues(alpha: 0.3),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Center(child: Icon(Icons.auto_stories, size: 80, color: cs.primary.withValues(alpha: 0.4))),
          ),
          const SizedBox(height: 24),
          Text(detail?.title ?? "", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          if (detail?.author != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(detail!.author!, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)))),
        ]),
      ),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  final AudioPlayer player;
  final bool isReady;
  final double speed;
  final int currentChapter;
  final BookDetail? detail;
  final String Function(Duration) fmt;
  final ColorScheme cs;
  final String playMode;
  final VoidCallback onPlayModeToggle;
  final void Function(double) onSpeedChange;
  final void Function(double) onSeek;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;

  const _PlayerControls({
    required this.player, required this.isReady, required this.speed, required this.currentChapter,
    required this.detail, required this.fmt, required this.cs, required this.playMode,
    required this.onPlayModeToggle, required this.onSpeedChange, required this.onSeek,
    required this.onPrevChapter, required this.onNextChapter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 模式切换
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ModeChip(label: "只听书", icon: Icons.headphones, selected: playMode == "listen", onTap: () { if (playMode != "listen") onPlayModeToggle(); }),
          const SizedBox(width: 12),
          _ModeChip(label: "边看边听", icon: Icons.menu_book, selected: playMode == "read", onTap: () { if (playMode != "read") onPlayModeToggle(); }),
        ]),
        const SizedBox(height: 12),
        // 进度条
        StreamBuilder<Duration>(stream: player.positionStream, builder: (ctx, posSnap) {
          final pos = posSnap.data ?? Duration.zero;
          return StreamBuilder<Duration?>(stream: player.durationStream, builder: (ctx, durSnap) {
            final dur = durSnap.data ?? Duration.zero;
            final max = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
            return Column(children: [
              SliderTheme(data: SliderTheme.of(context).copyWith(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 12)), child: Slider(value: pos.inMilliseconds.toDouble().clamp(0, max), min: 0, max: max, onChanged: (v) => onSeek(v / 1000))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(fmt(pos), style: const TextStyle(fontSize: 11, color: Colors.grey)), Text(fmt(dur), style: const TextStyle(fontSize: 11, color: Colors.grey))])),
            ]);
          });
        }),
        const SizedBox(height: 8),
        // 主控制列
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(icon: const Icon(Icons.replay_10, size: 28), onPressed: isReady ? () => player.seek(player.position - const Duration(seconds: 15)) : null),
          IconButton(icon: const Icon(Icons.skip_previous, size: 32), onPressed: currentChapter > 0 && detail != null ? onPrevChapter : null),
          StreamBuilder<PlayerState>(stream: player.playerStateStream, builder: (ctx, snap) {
            final playing = snap.data?.playing ?? false;
            return Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary),
              child: IconButton(iconSize: 40, icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white), onPressed: isReady ? () => playing ? player.pause() : player.play() : null),
            );
          }),
          IconButton(icon: const Icon(Icons.skip_next, size: 32), onPressed: detail != null && currentChapter < detail.chapters.length - 1 ? onNextChapter : null),
          IconButton(icon: const Icon(Icons.forward_30, size: 28), onPressed: isReady ? () => player.seek(player.position + const Duration(seconds: 15)) : null),
        ]),
        const SizedBox(height: 8),
        // 底部信息
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.speed, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text("${speed}x", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 16),
          const Icon(Icons.download_outlined, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          const Text("下载", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ]),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: selected ? Colors.white : Colors.grey, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }
}

class _ReadMode extends StatelessWidget {
  final BookDetail detail;
  final int currentLine;
  final ScrollController scrollCtrl;
  final AudioPlayer player;

  const _ReadMode({required this.detail, required this.currentLine, required this.scrollCtrl, required this.player});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: ListView.builder(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(20),
        itemCount: detail.transcript.length,
        itemBuilder: (ctx, i) {
          final t = detail.transcript[i];
          final active = i == currentLine;
          return GestureDetector(
            onTap: () => player.seek(Duration(seconds: t.start.toInt())),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: active ? cs.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: active ? Border.all(color: cs.primary.withValues(alpha: 0.3)) : null,
              ),
              child: Text(t.text, style: TextStyle(
                fontSize: active ? 18 : 16,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? cs.primary : cs.onSurface,
                height: 1.6,
              )),
            ),
          );
        },
      ),
    );
  }
}
