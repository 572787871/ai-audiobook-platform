import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:just_audio/just_audio.dart";
import "../theme/app_theme.dart";
import "../providers/book_provider.dart";
import "../providers/local_tts_provider.dart";
import "../widgets/common_widgets.dart";
import "../models/book.dart";
import "../models/local_tts.dart";

class BrowseReadScreen extends StatefulWidget {
  final int bookId;
  const BrowseReadScreen({super.key, required this.bookId});

  @override
  State<BrowseReadScreen> createState() => _BrowseReadScreenState();
}

class _BrowseReadScreenState extends State<BrowseReadScreen> {
  BookDetail? detail;
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scrollCtrl = ScrollController();
  bool _loading = true;
  String? _error;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _autoScroll = true;
  double _fontSize = 18;
  int _bgIndex = 0;
  bool _nightMode = false;
  List<TtsSegment> _localSegments = [];

  final _bgColors = [
    const Color(0xFFF5F7FA),
    const Color(0xFFFDF6E3),
    const Color(0xFFF0EBE0),
    const Color(0xFFE8E8E8)
  ];

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
      _autoScrollIfNeeded(_position.inSeconds.toDouble());
    });
    _player.playingStream.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d =
          await context.read<BookProvider>().fetchBookDetail(widget.bookId);
      if (!mounted) return;
      setState(() {
        detail = d;
        _loading = false;
      });
      final segments =
          await context.read<LocalTtsProvider>().loadSegments(widget.bookId);
      final playable = segments
          .where((s) => s.audioPath != null && s.audioPath!.isNotEmpty)
          .toList();
      if (playable.isNotEmpty) {
        _localSegments = playable;
        await _player.setAudioSource(ConcatenatingAudioSource(
            children: playable
                .map((s) => AudioSource.uri(Uri.file(s.audioPath!)))
                .toList()));
      } else if (d.audioUrl != null && d.audioUrl!.isNotEmpty) {
        try {
          final uri = Uri.tryParse(d.audioUrl!);
          if (uri == null || !uri.hasScheme) {
            throw FormatException("无效的音频地址: ${d.audioUrl}");
          }
          await _player.setAudioSource(AudioSource.uri(uri));
        } catch (e) {
          setState(() => _error = "音频加载失败: $e");
        }
      } else {
        setState(() => _error = "音频尚未生成，请先在本机生成有声书");
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = "加载失败: $e";
          _loading = false;
        });
    }
  }

  int _currentLineIndex(List<TranscriptLine> lines, double posSec) {
    for (int i = 0; i < lines.length; i++) {
      if (posSec >= lines[i].start && posSec < lines[i].end) return i;
    }
    return -1;
  }

  void _autoScrollIfNeeded(double posSec) {
    if (!_autoScroll || detail == null || _scrollCtrl.positions.isEmpty) return;
    final idx = _currentLineIndex(_effectiveTranscript(), posSec);
    if (idx < 0) return;
    final offset = idx * 60.0;
    _scrollCtrl.animateTo(offset,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _player.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: _nightMode
          ? const Color(0xFF0D0F1A)
          : (isDark ? AppTheme.bgDark : _bgColors[_bgIndex]),
      body: SafeArea(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: cs.primary))
              : _error != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 48, color: AppTheme.danger),
                                const SizedBox(height: 12),
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                    onPressed: _loadDetail,
                                    child: const Text("重试"))
                              ])))
                  : _buildReader(isDark, cs)),
      bottomNavigationBar:
          detail == null ? null : _buildBottomController(isDark, cs),
    );
  }

  Widget _buildReader(bool isDark, ColorScheme cs) {
    final lines = _effectiveTranscript();
    final idx = _currentLineIndex(lines, _position.inSeconds.toDouble());

    return Column(children: [
      // 顶部工具栏
      SafeArea(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(
                    icon: Icon(Icons.arrow_back,
                        color: _nightMode ? Colors.white70 : cs.onSurface),
                    onPressed: () => Navigator.pop(context)),
                const Spacer(),
                IconButton(
                    icon: Icon(Icons.auto_stories_outlined,
                        color: _nightMode ? Colors.white70 : cs.onSurface),
                    onPressed: () => _showSettingsSheet(context)),
                IconButton(
                    icon: Icon(Icons.nightlight_round,
                        color: _nightMode ? Colors.amber : cs.onSurface),
                    onPressed: () => setState(() => _nightMode = !_nightMode)),
              ]))),

      // 内容：直接展示字幕/段落，支持同步高亮
      Expanded(
        child: lines.isEmpty
            ? Center(
                child: Text("暂无字幕内容",
                    style: TextStyle(
                        color: _nightMode ? Colors.white38 : Colors.grey)))
            : ListView.builder(
                controller: _scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                itemCount: lines.length,
                itemBuilder: (c, i) {
                  final line = lines[i];
                  final isCurrent = i == idx;
                  return GestureDetector(
                    onTap: () =>
                        _player.seek(Duration(seconds: line.start.toInt())),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? cs.primary
                                .withValues(alpha: _nightMode ? 0.15 : 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        line.text,
                        style: TextStyle(
                          fontSize: _fontSize,
                          height: 1.8,
                          color: isCurrent
                              ? cs.primary
                              : (_nightMode ? Colors.white70 : cs.onSurface),
                          fontWeight:
                              isCurrent ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  List<TranscriptLine> _effectiveTranscript() {
    final d = detail;
    if (d == null) return [];
    if (d.transcript.isNotEmpty) return d.transcript;
    return _localSegments
        .map((s) => TranscriptLine(
            start: s.startTime, end: s.endTime, text: s.originalText))
        .toList();
  }

  Widget _buildBottomController(bool isDark, ColorScheme cs) {
    final bgColor = _nightMode
        ? const Color(0xFF1A1D2E)
        : (isDark ? AppTheme.cardDark : Colors.white);
    return Container(
      decoration: BoxDecoration(
          color: bgColor,
          boxShadow:
              AppTheme.cardShadow(Colors.black, opacity: 0.1, blur: 16, y: -2)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
          top: false,
          child: Row(children: [
            Hero(
                tag: "book_cover_${detail!.id}",
                child: BookCover(
                    title: detail!.title,
                    coverUrl: detail!.coverUrl,
                    width: 40,
                    height: 40,
                    radius: AppTheme.radiusSm)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(detail!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _nightMode ? Colors.white : cs.onSurface)),
                  Text(
                      "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}",
                      style: TextStyle(
                          fontSize: 11,
                          color: _nightMode
                              ? Colors.white54
                              : cs.onSurface.withValues(alpha: 0.4))),
                ])),
            IconButton(
                onPressed: _previousLine,
                icon: Icon(Icons.skip_previous_rounded,
                    color: _nightMode ? Colors.white : cs.onSurface)),
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
                child: IconButton(
                    onPressed: () {
                      if (_isPlaying)
                        _player.pause();
                      else
                        _player.play();
                    },
                    icon: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24))),
            IconButton(
                onPressed: _nextLine,
                icon: Icon(Icons.skip_next_rounded,
                    color: _nightMode ? Colors.white : cs.onSurface)),
          ])),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl))),
        builder: (ctx) => SafeArea(
            child: StatefulBuilder(
                builder: (ctx, setSheet) =>
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(height: 12),
                      Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 16),
                      Text("阅读设置",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      // 字体大小
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(children: [
                            Text("字体",
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            IconButton(
                                onPressed: () {
                                  setState(() => _fontSize =
                                      (_fontSize - 1).clamp(12, 28));
                                  setSheet(() {});
                                },
                                icon: Icon(Icons.remove_circle_outline)),
                            Text("${_fontSize.toInt()}",
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            IconButton(
                                onPressed: () {
                                  setState(() => _fontSize =
                                      (_fontSize + 1).clamp(12, 28));
                                  setSheet(() {});
                                },
                                icon: Icon(Icons.add_circle_outline))
                          ])),
                      const SizedBox(height: 12),
                      // 背景色
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(children: [
                            Text("背景",
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            ..._bgColors.asMap().entries.map((e) =>
                                GestureDetector(
                                    onTap: () {
                                      setState(() => _bgIndex = e.key);
                                      setSheet(() {});
                                    },
                                    child: Container(
                                        width: 32,
                                        height: 32,
                                        margin: const EdgeInsets.only(left: 6),
                                        decoration: BoxDecoration(
                                            color: e.value,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: _bgIndex == e.key
                                                    ? AppTheme.primaryLight
                                                    : Colors.transparent,
                                                width: 2)))))
                          ])),
                      const SizedBox(height: 12),
                      // 自动滚动
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(children: [
                            Text("自动滚动",
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Switch(
                                value: _autoScroll,
                                onChanged: (v) {
                                  setState(() => _autoScroll = v);
                                  setSheet(() {});
                                })
                          ])),
                      const SizedBox(height: 16),
                    ]))));
  }

  Future<void> _seekToLine(int index) async {
    final lines = _effectiveTranscript();
    if (index < 0 || index >= lines.length) return;
    await _player
        .seek(Duration(milliseconds: (lines[index].start * 1000).round()));
  }

  Future<void> _previousLine() async {
    final lines = _effectiveTranscript();
    if (lines.isEmpty) return;
    final idx = _currentLineIndex(lines, _position.inSeconds.toDouble());
    await _seekToLine(idx > 0 ? idx - 1 : 0);
  }

  Future<void> _nextLine() async {
    final lines = _effectiveTranscript();
    if (lines.isEmpty) return;
    final idx = _currentLineIndex(lines, _position.inSeconds.toDouble());
    final next =
        idx < 0 ? 0 : (idx + 1 >= lines.length ? lines.length - 1 : idx + 1);
    await _seekToLine(next);
  }
}
