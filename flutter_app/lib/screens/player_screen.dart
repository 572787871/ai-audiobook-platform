/// 播放器页面：播放/暂停/拖动/倍速/字幕/章节
import "dart:async";
import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:provider/provider.dart";
import "../providers/book_provider.dart";
import "../models/book.dart";

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
  StreamSubscription? _posSub;

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
      if (detail == null || detail.audioUrl == null) {
        setState(() { _error = "音频尚未生成"; _loading = false; });
        return;
      }
      final url = detail.audioUrl!;
      // 后端 URL 可能是 localhost 链接，把它替换成 baseUrl
      final fullUrl = url.startsWith("http") ? url : "${ApiService.baseUrl}$url";
      await _player.setAudioSource(AudioSource.uri(Uri.parse(fullUrl)));
      _posSub = _player.positionStream.listen((pos) {
        final d = detail;
        if (d == null) return;
        // 找当前章节
        for (int i = 0; i < d.chapters.length; i++) {
          final c = d.chapters[i];
          if (pos.inSeconds >= c.start.toInt() && pos.inSeconds < c.end.toInt()) {
            if (_currentChapter != i) setState(() => _currentChapter = i);
            break;
          }
        }
      });
      setState(() { _isReady = true; _loading = false; });
      _player.play();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

    String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}';
    }
    return '${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}';
  }

  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookProvider>();
    final detail = bp.currentDetail;
    return Scaffold(
      appBar: AppBar(title: Text(detail?.title ?? "播放"), actions: [
        IconButton(icon: const Icon(Icons.subject), onPressed: () => setState(() => _showTranscript = !_showTranscript)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _PlayerBody(
                  player: _player,
                  detail: detail,
                  isReady: _isReady,
                  speed: _speed,
                  currentChapter: _currentChapter,
                  showTranscript: _showTranscript,
                  onSpeedChange: (v) => setState(() { _speed = v; _player.setSpeed(v); }),
                  onSeek: (p) => _player.seek(Duration(seconds: p.toInt())),
                  fmt: _fmt,
                ),
    );
  }
}

class _PlayerBody extends StatelessWidget {
  final AudioPlayer player;
  final BookDetail? detail;
  final bool isReady;
  final double speed;
  final int currentChapter;
  final bool showTranscript;
  final void Function(double) onSpeedChange;
  final void Function(double) onSeek;
  final String Function(Duration) fmt;

  const _PlayerBody({
    required this.player,
    required this.detail,
    required this.isReady,
    required this.speed,
    required this.currentChapter,
    required this.showTranscript,
    required this.onSpeedChange,
    required this.onSeek,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Center(child: SizedBox(width: 220, height: 220, child: ClipRRect(borderRadius: BorderRadius.circular(20),
          child: detail?.coverUrl != null ? Image.network(detail!.coverUrl!, fit: BoxFit.cover)
              : Container(color: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.book, size: 96, color: Theme.of(context).colorScheme.primary))))),
        const SizedBox(height: 24),
        Center(child: Text(detail?.title ?? "", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        if (detail?.author != null) Center(child: Text(detail!.author!, style: TextStyle(fontSize: 16, color: Colors.grey.shade600))),
        const SizedBox(height: 12),
        if (detail?.chapters.isNotEmpty == true)
          Center(child: Text(detail!.chapters[currentChapter].title, style: const TextStyle(color: Colors.grey))),
        const SizedBox(height: 24),

        // 进度条
        StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (ctx, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            return StreamBuilder<Duration?>(
              stream: player.durationStream,
              builder: (ctx, durSnap) {
                final dur = durSnap.data ?? (detail?.audioDuration?.let((v) => Duration(seconds: v.toInt())) ?? Duration.zero);
                return Column(children: [
                  Slider(value: pos.inMilliseconds.toDouble(),
                    min: 0,
                    max: (dur.inMilliseconds.isInfinite || dur.inMilliseconds == 0) ? 1.0 : dur.inMilliseconds.toDouble(),
                    onChanged: (v) => onSeek(v / 1000),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(fmt(pos), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(fmt(dur), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ]);
              },
            );
          },
        ),

        // 控制列
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(icon: const Icon(Icons.replay_10, size: 36), onPressed: () => player.seek(player.position - const Duration(seconds: 10))),
          StreamBuilder<PlayerState>(stream: player.playerStateStream, builder: (ctx, snap) {
            final playing = snap.data?.playing ?? false;
            return IconButton(iconSize: 64, icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
              onPressed: isReady ? () => playing ? player.pause() : player.play() : null);
          }),
          IconButton(icon: const Icon(Icons.forward_30, size: 36), onPressed: () => player.seek(player.position + const Duration(seconds: 30))),
        ]),

        const SizedBox(height: 16),
        // 倍速
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text("倍速："),
          PopupMenuButton<double>(initialValue: speed, onSelected: onSpeedChange, itemBuilder: (_) => const [PopupMenuItem(value: 0.5, child: Text("0.5×")), PopupMenuItem(value: 0.75, child: Text("0.75×")), PopupMenuItem(value: 1.0, child: Text("1.0×")), PopupMenuItem(value: 1.5, child: Text("1.5×")), PopupMenuItem(value: 2.0, child: Text("2.0×"))], child: Text("\$speed×", style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),

        if (detail?.chapters.isNotEmpty == true) ...[
          const SizedBox(height: 24),
          const Text("章节", style: TextStyle(fontWeight: FontWeight.bold)),
          ...detail!.chapters.asMap().entries.map((e) => ListTile(
            dense: true,
            selected: e.key == currentChapter,
            leading: Text("#\${e.value.index + 1}"),
            title: Text(e.value.title, style: TextStyle(color: e.key == currentChapter ? Theme.of(context).colorScheme.primary : null)),
            subtitle: Text("\${e.value.start.toStringAsFixed(1)}s"),
            onTap: () => onSeek(e.value.start),
          )),
        ],

        if (showTranscript && detail?.transcript.isNotEmpty == true) ...[
          const SizedBox(height: 24),
          const Text("字幕", style: TextStyle(fontWeight: FontWeight.bold)),
          ...detail!.transcript.map((t) => StreamBuilder<Duration>(stream: player.positionStream, builder: ((ctx, snap) {
            final pos = snap.data?.inSeconds ?? 0;
            final active = (pos >= t.start.toInt() && pos < t.end.toInt());
            return Container(
              color: active ? Theme.of(context).colorScheme.primaryContainer : null,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 60, child: Text("\${t.start.toStringAsFixed(1)}s", style: TextStyle(fontSize: 12, color: active ? Theme.of(context).colorScheme.primary : Colors.grey))),
                const SizedBox(width: 8),
                Expanded(child: Text(t.text, style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal))),
              ]),
            );
          }))),
        ],
      ],
    );
  }
}

extension on double {
  T? let<T>(T Function(double) fn) => fn(this);
}
