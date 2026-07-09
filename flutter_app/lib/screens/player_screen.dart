import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:just_audio/just_audio.dart";
import "../theme/app_theme.dart";
import "../widgets/common_widgets.dart";
import "../providers/book_provider.dart";
import "../models/book.dart";

class PlayerScreen extends StatefulWidget {
  final int bookId;
  const PlayerScreen({super.key, required this.bookId});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  BookDetail? detail;
  final AudioPlayer _player = AudioPlayer();
  bool _loading = true;
  String? _error;
  int _currentChapter = 0;
  double _speed = 1.0;
  bool _showTranscript = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  int _sleepTimerMinutes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDetail();
    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _totalDuration = dur);
    });
    _player.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
  }

  Future<void> _loadDetail() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await context.read<BookProvider>().fetchBookDetail(widget.bookId);
      if (!mounted) return;
      setState(() { detail = d; _loading = false; });
      if (d.audioUrl != null && d.audioUrl!.isNotEmpty) {
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
        setState(() => _error = "音频尚未生成或后端未返回 audio_url");
      }
    } catch (e) {
      if (mounted) setState(() { _error = "加载失败: $e"; _loading = false; });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _player.stop();
  }

  Future<void> _seek(int seconds) async {
    final newPos = _position + Duration(seconds: seconds);
    if (newPos < Duration.zero) return;
    if (newPos > _totalDuration) return;
    await _player.seek(newPos);
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  void _setSpeed(double s) {
    _player.setSpeed(s);
    setState(() => _speed = s);
  }

  void _startSleepTimer(int minutes) {
    setState(() => _sleepTimerMinutes = minutes);
    if (minutes > 0) {
      Future.delayed(Duration(minutes: minutes), () {
        if (mounted && _player.playing) {
          _player.pause();
          setState(() => _sleepTimerMinutes = 0);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("定时关闭已执行")));
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: isDark ? AppTheme.playerGradient : LinearGradient(colors: [AppTheme.primaryLight.withValues(alpha: 0.1), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: _loading
              ? _buildSkeleton()
              : _error != null
                  ? _buildError()
                  : _buildPlayerContent(),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SkeletonBox(height: 280, radius: AppTheme.radiusXl),
      const SizedBox(height: 32),
      SkeletonBox(height: 28, width: 200),
      const SizedBox(height: 8),
      SkeletonBox(height: 16, width: 120),
      const SizedBox(height: 48),
      SkeletonBox(height: 4, radius: AppTheme.radiusFull),
    ]));
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.danger.withValues(alpha: 0.5)),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.danger)),
      ),
      const SizedBox(height: 24),
      OutlinedButton(onPressed: _loadDetail, child: const Text("重试")),
    ]));
  }

  Widget _buildPlayerContent() {
    final d = detail!;
    final cs = Theme.of(context).colorScheme;
    final transcript = d.transcript;
    final currentLine = _findCurrentLine(transcript);

    return Column(children: [
      // 顶部
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Row(children: [
        IconButton(icon: Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: cs.onSurface.withValues(alpha: 0.6)), onPressed: () => Navigator.pop(context)),
        const Spacer(),
        Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(icon: Icon(Icons.more_horiz, color: cs.onSurface.withValues(alpha: 0.6)), onPressed: () {}),
      ])),

      // 封面
      Expanded(flex: 4, child: Center(child: Hero(tag: "book_cover_${d.id}", child: BookCover(title: d.title, coverUrl: d.coverUrl, width: 260, height: 320, radius: AppTheme.radiusLg)))),

      // 标题
      Padding(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16), child: Column(children: [
        Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: cs.onSurface)),
        if (d.author != null && d.author!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(d.author!, style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.5))),
        ],
      ])),

      // 字幕预览
      if (transcript.isNotEmpty && currentLine != null)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(AppTheme.radiusMd)), child: Text(currentLine.text, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: cs.onSurface)))),

      // 进度条
      Padding(padding: const EdgeInsets.fromLTRB(32, 16, 32, 8), child: Column(children: [
        ClipRRect(borderRadius: BorderRadius.circular(AppTheme.radiusFull), child: SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 12), trackShape: const RoundedRectSliderTrackShape()), child: Slider(value: _position.inSeconds.toDouble(), max: _totalDuration.inSeconds.toDouble().clamp(1, double.infinity), onChanged: (v) => _player.seek(Duration(seconds: v.toInt()))))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_fmtDuration(_position), style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
          Text(_fmtDuration(_totalDuration), style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
        ])),
      ])),

      // 控制按钮
      Expanded(flex: 2, child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        IconButton(onPressed: () => _seek(-15), icon: Icon(Icons.replay_10_rounded, size: 36, color: cs.onSurface.withValues(alpha: 0.7))),
        IconButton(onPressed: _previousChapter, icon: Icon(Icons.skip_previous_rounded, size: 40, color: cs.onSurface)),
        Container(width: 64, height: 64, decoration: BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle, boxShadow: AppTheme.glowShadow(AppTheme.primaryLight, opacity: 0.3)), child: IconButton(onPressed: _togglePlay, icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32, color: Colors.white))),
        IconButton(onPressed: _nextChapter, icon: Icon(Icons.skip_next_rounded, size: 40, color: cs.onSurface)),
        IconButton(onPressed: () => _seek(15), icon: Icon(Icons.forward_10_rounded, size: 36, color: cs.onSurface.withValues(alpha: 0.7))),
      ]))),

      // 工具栏
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _ToolButton(icon: Icons.speed_rounded, label: "${_speed}x", onTap: () => _showSpeedSheet(context)),
        _ToolButton(icon: Icons.timer_outlined, label: _sleepTimerMinutes > 0 ? "${_sleepTimerMinutes}分" : "定时", onTap: () => _showSleepSheet(context)),
        _ToolButton(icon: Icons.list_rounded, label: "目录", onTap: () { _showChaptersSheet(context); }),
        _ToolButton(icon: Icons.subtitles_outlined, label: "字幕", active: _showTranscript, onTap: () => setState(() => _showTranscript = !_showTranscript)),
        _ToolButton(icon: Icons.download_outlined, label: "下载", onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("下载功能开发中")))),
      ])),

      // 字幕展开
      if (_showTranscript && transcript.isNotEmpty)
        Expanded(flex: 3, child: Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(AppTheme.radiusMd)), child: ListView.builder(itemCount: transcript.length, itemBuilder: (ctx, i) {
          final line = transcript[i];
          final isCurrent = _position.inSeconds >= line.start.toInt() && _position.inSeconds < line.end.toInt();
          return GestureDetector(onTap: () => _player.seek(Duration(seconds: line.start.toInt())), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(line.text, style: TextStyle(fontSize: 14, color: isCurrent ? cs.primary : cs.onSurface.withValues(alpha: 0.5), fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal))));
        }))),
    ]);
  }

  TranscriptLine? _findCurrentLine(List<TranscriptLine> lines) {
    final pos = _position.inSeconds.toDouble();
    for (final line in lines) {
      if (pos >= line.start && pos < line.end) return line;
    }
    return null;
  }

  void _showSpeedSheet(BuildContext context) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(context: context, backgroundColor: Theme.of(context).colorScheme.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl))), builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12),
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 16),
      Text("播放速度", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: speeds.map((s) {
        final active = _speed == s;
        return GestureDetector(onTap: () { _setSpeed(s); Navigator.pop(ctx); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: active ? AppTheme.primaryLight : Theme.of(context).colorScheme.surface, border: Border.all(color: active ? AppTheme.primaryLight : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(AppTheme.radiusFull)), child: Text("${s}x", style: TextStyle(fontWeight: FontWeight.w600, color: active ? Colors.white : Theme.of(context).colorScheme.onSurface))));
      }).toList()),
      const SizedBox(height: 16),
    ])));
  }

  void _showSleepSheet(BuildContext context) {
    final options = [0, 15, 30, 45, 60];
    showModalBottomSheet(context: context, backgroundColor: Theme.of(context).colorScheme.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl))), builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12),
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 16),
      Text("定时关闭", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      for (final o in options) ListTile(title: Text(o == 0 ? "关闭定时" : "$o 分钟"), trailing: _sleepTimerMinutes == o ? Icon(Icons.check, color: AppTheme.primaryLight) : null, onTap: () { _startSleepTimer(o); Navigator.pop(ctx); }),
      const SizedBox(height: 8),
    ])));
  }

  void _showChaptersSheet(BuildContext context) {
    final chapters = detail!.chapters;
    if (chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("暂无章节")));
      return;
    }
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl))), builder: (ctx) => DraggableScrollableSheet(expand: false, maxChildSize: 0.7, initialChildSize: 0.5, minChildSize: 0.3, builder: (c, sc) => Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl))), child: Column(children: [
      Container(margin: const EdgeInsets.all(12), width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
      Text("目录", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Expanded(child: ListView.builder(controller: sc, itemCount: chapters.length, itemBuilder: (c, i) => ListTile(leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: i == _currentChapter ? AppTheme.primaryLight : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppTheme.radiusSm)), child: Center(child: Text("${i + 1}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: i == _currentChapter ? Colors.white : Theme.of(context).colorScheme.primary)))), title: Text(chapters[i].title, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () { _seekToChapter(i); Navigator.pop(context); }))),
    ]))));
  }

  String _fmtDuration(Duration d) {
    return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  Future<void> _seekToChapter(int index) async {
    final chapters = detail?.chapters ?? [];
    if (index < 0 || index >= chapters.length) return;
    setState(() => _currentChapter = index);
    await _player.seek(Duration(milliseconds: (chapters[index].start * 1000).round()));
  }

  Future<void> _previousChapter() async {
    final chapters = detail?.chapters ?? [];
    if (chapters.isEmpty) {
      await _seek(-30);
      return;
    }
    final target = _currentChapter > 0 ? _currentChapter - 1 : 0;
    await _seekToChapter(target);
  }

  Future<void> _nextChapter() async {
    final chapters = detail?.chapters ?? [];
    if (chapters.isEmpty) {
      await _seek(30);
      return;
    }
    final target = _currentChapter < chapters.length - 1 ? _currentChapter + 1 : _currentChapter;
    await _seekToChapter(target);
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _ToolButton({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(onTap: onTap, child: Column(children: [
      Icon(icon, size: 22, color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.5)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11, color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.4), fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
    ]));
  }
}
