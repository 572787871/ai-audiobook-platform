import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import '../../../theme/app_theme.dart';
import '../../library/models/book.dart';
import '../../library/models/book_file_type.dart';
import '../../library/services/book_repository.dart';
import '../services/reading_settings_service.dart';

/// 阅读器：分页阅读，支持字体/背景/行距，自动保存进度。
class ReaderPage extends StatefulWidget {
  final Book book;
  final BookRepositoryBase? repository;

  const ReaderPage({super.key, required this.book, this.repository});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  BookRepositoryBase get _repo => widget.repository ?? BookRepository.instance;

  List<String> _pages = [];
  int _pageIndex = 0;
  ReadingSettings _settings = const ReadingSettings();
  bool _loading = true;
  bool _showToolbar = false;
  DateTime? _openedAt;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _init();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveReadingTime();
    super.dispose();
  }

  Future<void> _init() async {
    _settings = await ReadingSettingsService.instance.get();
    final content = await _loadContent();
    if (content.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _buildPages(content);
    if (mounted) setState(() => _loading = false);
  }

  Future<String> _loadContent() async {
    if (widget.book.fileType != BookFileType.txt) return '';
    final file = File(widget.book.contentPath ?? '');
    if (!await file.exists()) return '';
    try {
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  void _buildPages(String content) {
    const perPage = 900;
    final buffer = StringBuffer();
    var count = 0;
    final pages = <String>[];
    final paragraphs = content.split(String.fromCharCode(10));
    for (final para in paragraphs) {
      if (para.isEmpty) continue;
      if (count + para.length > perPage && buffer.isNotEmpty) {
        pages.add(buffer.toString());
        buffer.clear();
        count = 0;
      }
      buffer.writeln(para);
      count += para.length;
    }
    if (buffer.isNotEmpty) pages.add(buffer.toString());
    _pages = pages.isEmpty ? [''] : pages;

    final savedPct = widget.book.readingProgress;
    if (savedPct > 0 && _pages.isNotEmpty) {
      _pageIndex = ((savedPct * (_pages.length - 1)).round())
          .clamp(0, _pages.length - 1);
    }
  }

  void _saveProgress() {
    final pct = _pages.isEmpty ? 0.0 : (_pageIndex / _pages.length).clamp(0.0, 1.0);
    final updated = widget.book.copyWith(
      readingProgress: pct,
      lastReadOffset: _pageIndex,
      lastReadChapter: '正文',
      updatedAt: DateTime.now(),
    );
    _repo.save(updated);
  }

  void _saveReadingTime() {
    if (_openedAt == null) return;
    final sec = DateTime.now().difference(_openedAt!).inSeconds;
    if (sec <= 0) return;
    final updated = widget.book.copyWith(
      readingTimeSec: widget.book.readingTimeSec + sec,
      updatedAt: DateTime.now(),
    );
    _repo.save(updated);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _saveProgress);
  }

  void _nextPage() {
    if (_pageIndex < _pages.length - 1) {
      setState(() => _pageIndex++);
      _saveProgress();
      _scheduleSave();
    }
  }

  void _prevPage() {
    if (_pageIndex > 0) {
      setState(() => _pageIndex--);
      _saveProgress();
      _scheduleSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = _bgColors();
    return CupertinoPageScaffold(
      backgroundColor: themeColors.background,
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : GestureDetector(
                onTap: () => setState(() => _showToolbar = !_showToolbar),
                onHorizontalDragEnd: (d) {
                  if (d.primaryVelocity != null && d.primaryVelocity! < 0) {
                    _nextPage();
                  } else if (d.primaryVelocity != null && d.primaryVelocity! > 0) {
                    _prevPage();
                  }
                },
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: _pages.isEmpty
                                ? Center(
                                    child: Text('暂无正文内容',
                                        style: TextStyle(color: themeColors.text)))
                                : SingleChildScrollView(
                                    child: Text(
                                      _pages[_pageIndex],
                                      style: TextStyle(
                                        fontSize: _settings.fontSize,
                                        height: _settings.lineHeight,
                                        color: themeColors.text,
                                        fontFamily: _settings.fontFamily == 'system'
                                            ? null
                                            : _settings.fontFamily,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              Text(_progressText(), style: TextStyle(fontSize: 12, color: themeColors.subtext)),
                              const Spacer(),
                              Text('${_pageIndex + 1}/${_pages.length}', style: TextStyle(fontSize: 12, color: themeColors.subtext)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_showToolbar) _buildToolbar(themeColors),
                  ],
                ),
              ),
      ),
    );
  }

  String _progressText() {
    if (_pages.isEmpty) return '0%';
    final pct = ((_pageIndex + 1) / _pages.length * 100).round();
    return '$pct%';
  }

  _ThemeColors _bgColors() {
    switch (_settings.theme) {
      case ReaderTheme.day:
        return _ThemeColors(const Color(0xFFFFFFFF), const Color(0xFF000000), const Color(0xFF8E8E93));
      case ReaderTheme.sepia:
        return _ThemeColors(const Color(0xFFF5ECD8), const Color(0xFF5B4636), const Color(0xFF9C8A6B));
      case ReaderTheme.dark:
        return _ThemeColors(const Color(0xFF1C1C1E), const Color(0xFFE5E5EA), const Color(0xFF8E8E93));
      case ReaderTheme.night:
        return _ThemeColors(const Color(0xFF000000), const Color(0xFFBDBDBD), const Color(0xFF757575));
    }
  }

  Widget _buildToolbar(_ThemeColors c) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: c.background,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _toolBtn('目录', CupertinoIcons.list_bullet, () => _showToc()),
            _toolBtn('进度', CupertinoIcons.percent, () => _showProgress()),
            _toolBtn('字体', CupertinoIcons.textformat, () => _showFont()),
            _toolBtn('更多', CupertinoIcons.ellipsis, () => _showMore()),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(String label, IconData icon, VoidCallback onTap) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryText),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  void _showToc() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('目录'),
        message: const Text('正文（后续自动升级为章节列表）'),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('关闭'),
        ),
      ),
    );
  }

  void _showProgress() {
    final pct = _progressText();
    final mins = (widget.book.readingTimeSec / 60).floor();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('阅读进度'),
        content: Text('当前进度：$pct  ·  阅读时长：$mins 分钟'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('好的'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showFont() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('字体与排版'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _changeFontSize(2);
            },
            child: const Text('增大字号'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _changeFontSize(-2);
            },
            child: const Text('减小字号'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _changeLineHeight(0.1);
            },
            child: const Text('增大行距'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _changeLineHeight(-0.1);
            },
            child: const Text('减小行距'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('关闭'),
        ),
      ),
    );
  }

  void _showMore() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('更多'),
        actions: ReaderTheme.values
            .map((t) => CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _changeTheme(t);
                  },
                  child: Text('背景：${t.label}'),
                ))
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('关闭'),
        ),
      ),
    );
  }

  void _changeFontSize(double delta) {
    final v = (_settings.fontSize + delta).clamp(12.0, 30.0);
    _applySettings(_settings.copyWith(fontSize: v));
  }

  void _changeLineHeight(double delta) {
    final v = (_settings.lineHeight + delta).clamp(1.2, 2.4);
    _applySettings(_settings.copyWith(lineHeight: v));
  }

  void _changeTheme(ReaderTheme theme) {
    _applySettings(_settings.copyWith(theme: theme));
  }

  void _applySettings(ReadingSettings s) {
    ReadingSettingsService.instance.save(s);
    setState(() => _settings = s);
  }
}

class _ThemeColors {
  const _ThemeColors(this.background, this.text, this.subtext);
  final Color background;
  final Color text;
  final Color subtext;
}
