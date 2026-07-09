import "dart:async";
import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:provider/provider.dart";
import "../providers/book_provider.dart";
import "../services/api_service.dart";

class BrowseReadScreen extends StatefulWidget {
  final int bookId;
  const BrowseReadScreen({super.key, required this.bookId});

  @override
  State<BrowseReadScreen> createState() => _BrowseReadScreenState();
}

class _BrowseReadScreenState extends State<BrowseReadScreen> {
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scrollCtrl = ScrollController();
  bool _loading = true;
  String? _error;
  int _currentLine = 0;
  double _speed = 1.0;
  double _fontSize = 18;
  double _lineHeight = 1.6;
  bool _darkBg = false;
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
      if (detail == null || detail.audioUrl == null || detail.transcript.isEmpty) {
        setState(() { _error = "暂无字幕数据"; _loading = false; }); return;
      }
      String rawUrl = detail.audioUrl!;
      String fullUrl = rawUrl.startsWith("http") ? rawUrl : "${ApiService.baseUrl}$rawUrl";
      await _player.setAudioSource(AudioSource.uri(Uri.parse(fullUrl)));
      _posSub = _player.positionStream.listen((pos) {
        final d = bp.currentDetail;
        if (d == null) return;
        for (int i = 0; i < d.transcript.length; i++) {
          final t = d.transcript[i];
          if (pos.inSeconds >= t.start.toInt() && pos.inSeconds < t.end.toInt()) {
            if (_currentLine != i) {
              setState(() => _currentLine = i);
              if (_scrollCtrl.hasClients) {
                final offset = i * (_fontSize * _lineHeight + 16);
                if (offset > _scrollCtrl.position.maxScrollExtent - 200 || offset < _scrollCtrl.position.pixels) {
                  _scrollCtrl.animateTo(offset.clamp(0, _scrollCtrl.position.maxScrollExtent), duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                }
              }
            }
            break;
          }
        }
      });
      setState(() => _loading = false);
      _player.play();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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
    final cs = Theme.of(context).colorScheme;
    final bp = context.watch<BookProvider>();
    final detail = bp.currentDetail;

    return Scaffold(
      backgroundColor: _darkBg ? const Color(0xFF1A1A2E) : cs.surface,
      appBar: AppBar(
        backgroundColor: _darkBg ? const Color(0xFF1A1A2E) : cs.surface,
        title: Text(detail?.title ?? "边看边听"),
        actions: [
          IconButton(icon: Icon(_darkBg ? Icons.light_mode : Icons.dark_mode), onPressed: () => setState(() => _darkBg = !_darkBg)),
          PopupMenuButton<String>(onSelected: (v) async {
            if (v == "font_up") setState(() => _fontSize = (_fontSize + 2).clamp(14, 32));
            if (v == "font_down") setState(() => _fontSize = (_fontSize - 2).clamp(14, 32));
            if (v == "line_up") setState(() => _lineHeight = (_lineHeight + 0.2).clamp(1.2, 2.5));
            if (v == "line_down") setState(() => _lineHeight = (_lineHeight - 0.2).clamp(1.2, 2.5));
            if (v == "speed") _showSpeedPicker(context);
          }, itemBuilder: (_) => const [
            PopupMenuItem(value: "font_up", child: ListTile(leading: Icon(Icons.text_increase), title: Text("增大字体"), dense: true)),
            PopupMenuItem(value: "font_down", child: ListTile(leading: Icon(Icons.text_decrease), title: Text("减小字体"), dense: true)),
            PopupMenuItem(value: "line_up", child: ListTile(leading: Icon(Icons.space_bar), title: Text("增大行距"), dense: true)),
            PopupMenuItem(value: "line_down", child: ListTile(leading: Icon(Icons.space_bar), title: Text("减小行距"), dense: true)),
            PopupMenuItem(value: "speed", child: ListTile(leading: Icon(Icons.speed), title: Text("倍速"), dense: true)),
          ]),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : detail == null || detail.transcript.isEmpty
                  ? const Center(child: Text("暂无字幕"))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(20),
                      itemCount: detail.transcript.length,
                      itemBuilder: (ctx, i) {
                        final t = detail.transcript[i];
                        final active = i == _currentLine;
                        return GestureDetector(
                          onTap: () => _player.seek(Duration(seconds: t.start.toInt())),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: active ? (_darkBg ? cs.primary.withValues(alpha: 0.3) : cs.primaryContainer.withValues(alpha: 0.5)) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: active ? Border.all(color: cs.primary.withValues(alpha: 0.4)) : null,
                            ),
                            child: Text(t.text, style: TextStyle(
                              fontSize: _fontSize,
                              fontWeight: active ? FontWeight.bold : FontWeight.normal,
                              color: active ? cs.primary : (_darkBg ? Colors.white70 : cs.onSurface),
                              height: _lineHeight,
                            )),
                          ),
                        );
                      },
                    ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _darkBg ? const Color(0xFF1A1A2E) : cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          StreamBuilder<PlayerState>(stream: _player.playerStateStream, builder: (ctx, snap) {
            final playing = snap.data?.playing ?? false;
            return Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary),
              child: IconButton(icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white), onPressed: () => playing ? _player.pause() : _player.play()),
            );
          }),
          const SizedBox(width: 8),
          StreamBuilder<Duration>(stream: _player.positionStream, builder: (ctx, snap) {
            final pos = snap.data ?? Duration.zero;
            return Text("${pos.inMinutes}:${(pos.inSeconds % 60).toString().padLeft(2, '0')}", style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)));
          }),
        ]),
      ),
    );
  }

  void _showSpeedPicker(BuildContext ctx) {
    showModalBottomSheet(context: ctx, builder: (bctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      for (final s in [0.8, 1.0, 1.2, 1.5, 2.0])
        ListTile(title: Text("${s}x"), trailing: s == _speed ? const Icon(Icons.check) : null,
            onTap: () { Navigator.pop(bctx); _player.setSpeed(s); setState(() => _speed = s); }),
    ]));
  }
}
