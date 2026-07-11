import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import '../../../theme/app_theme.dart';
import '../../library/models/book.dart';
import '../../library/models/book_file_type.dart';
import '../../library/services/book_repository.dart';
import '../services/reading_settings_service.dart';

/// 阅读器：分页阅读，沉浸模式，完整阅读设置与听书入口。
class ReaderPage extends StatefulWidget {
  final Book book;
  final BookRepositoryBase? repository;

  /// 正文加载器。生产环境为 null，默认从 `book.contentPath` 读取本地文件；
  /// 测试环境可注入内存字符串，避免依赖真实磁盘 IO。
  final Future<String> Function(Book book)? contentLoader;

  /// 起始阅读页索引（0 基）。默认 null：按 `book.readingProgress` 恢复上次位置。
  final int? initialPageIndex;

  const ReaderPage({
    super.key,
    required this.book,
    this.repository,
    this.contentLoader,
    this.initialPageIndex,
  });

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
  bool _listening = false;

  @override
  Widget build(BuildContext context) {
    final themeColors = _bgColors();
    return PopScope(
      canPop: true, // 不拦截 pop，保留 CupertinoPageRoute 默认 iOS 左边缘右滑
      child: CupertinoPageScaffold(
        backgroundColor: themeColors.background,
        navigationBar: _showToolbar
            ? CupertinoNavigationBar(
                leading: CupertinoButton(
                  key: const Key('reader_back'),
                  padding: EdgeInsets.zero,
                  onPressed: _handleBack,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.back, size: 20),
                      SizedBox(width: 2),
                      Text('返回'),
                    ],
                  ),
                ),
                middle: Text(widget.book.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _showMore,
                  child: const Icon(CupertinoIcons.ellipsis, size: 22),
                ),
              )
            : null,
        child: SafeArea(
          child: _loading
              ? const Center(child: CupertinoActivityIndicator())
              : GestureDetector(
                  key: const Key('reader_gesture'),
                  onTap: () => setState(() => _showToolbar = !_showToolbar),
                  onHorizontalDragEnd: (d) {
                    if (d.primaryVelocity != null && d.primaryVelocity! < 0) {
                      _nextPage();
                    } else if (d.primaryVelocity != null &&
                        d.primaryVelocity! > 0) {
                      _prevPage();
                    }
                  },
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: _settings.horizontalMargin,
                                vertical: 16,
                              ),
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
                                          fontWeight: FontWeight.values
                                              .firstWhere(
                                            (w) => w.value == _settings.fontWeight,
                                            orElse: () => FontWeight.normal,
                                          ),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: Row(
                              children: [
                                Text(_progressText(),
                                    style: TextStyle(
                                        fontSize: 12, color: themeColors.subtext)),
                                const Spacer(),
                                Text('${_pageIndex + 1}/${_pages.length}',
                                    style: TextStyle(
                                        fontSize: 12, color: themeColors.subtext)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_showToolbar) _buildBottomBar(),
                    ],
                  ),
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
        return _ThemeColors(const Color(0xFFFFFFFF), const Color(0xFF000000),
            const Color(0xFF8E8E93));
      case ReaderTheme.sepia:
        return _ThemeColors(const Color(0xFFF5ECD8), const Color(0xFF5B4636),
            const Color(0xFF9C8A6B));
      case ReaderTheme.dark:
        return _ThemeColors(const Color(0xFF1C1C1E), const Color(0xFFE5E5EA),
            const Color(0xFF8E8E93));
      case ReaderTheme.night:
        return _ThemeColors(const Color(0xFF000000), const Color(0xFFBDBDBD),
            const Color(0xFF757575));
    }
  }

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _init();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveProgress();
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
    final loader = widget.contentLoader;
    if (loader != null) {
      try {
        return await loader(widget.book);
      } catch (_) {
        return '';
      }
    }
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
    if (widget.initialPageIndex != null && _pages.isNotEmpty) {
      _pageIndex = widget.initialPageIndex!.clamp(0, _pages.length - 1);
    } else if (savedPct > 0 && _pages.isNotEmpty) {
      _pageIndex =
          ((savedPct * (_pages.length - 1)).round()).clamp(0, _pages.length - 1);
    }
  }

  Book _buildSavedBook() {
    final pct = _pages.isEmpty
        ? 0.0
        : (_pageIndex / _pages.length).clamp(0.0, 1.0);
    return widget.book.copyWith(
      readingProgress: pct,
      lastReadOffset: _pageIndex,
      lastReadChapter: '正文',
      updatedAt: DateTime.now(),
    ).withReadingToday(DateTime.now());
  }

  Future<Book> _saveProgress() async {
    final updated = _buildSavedBook();
    await _repo.save(updated);
    if (mounted) widget.book.copyWith(readingProgress: updated.readingProgress);
    return updated;
  }

  Future<void> _saveReadingTime() async {
    if (_openedAt == null) return;
    final sec = DateTime.now().difference(_openedAt!).inSeconds;
    if (sec <= 0) return;
    await _repo.save(widget.book.copyWith(
      readingTimeSec: widget.book.readingTimeSec + sec,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _handleBack() async {
    final updated = await _saveProgress();
    await _saveReadingTime();
    if (!mounted) return;
    Navigator.of(context).pop(updated);
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

  Widget _buildBottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: _bgColors().background,
          border: const Border(top: BorderSide(color: Color(0x1A000000))),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _toolBtn('目录', CupertinoIcons.list_bullet, _showToc),
            _toolBtn('进度', CupertinoIcons.percent, _showProgress),
            _toolBtn('听书', CupertinoIcons.speaker_2_fill, _toggleListen),
            _toolBtn('字体', CupertinoIcons.textformat, _showFont),
            _toolBtn('设置', CupertinoIcons.gear, _showSettings),
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
        content: Text(
            '当前进度：$pct  ·  阅读时长：$mins 分钟  ·  连续阅读 ${widget.book.streakDays} 天'),
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

  Future<void> _toggleListen() async {
    if (!_listening) {
      // 预留：后续接入 Kokoro 本地 TTS，实现文字同步高亮 + 自动滚动 + 句控。
      setState(() => _listening = true);
      await _repo.save(widget.book
          .copyWith(isListening: true, listenVoice: 'af_heart', listenRate: 1.0));
      if (mounted) _toast('AI 听书已开启（后续接入 Kokoro 本地引擎）');
    } else {
      setState(() => _listening = false);
      await _repo.save(widget.book.copyWith(isListening: false));
    }
  }

  void _toast(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(message),
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
        message: Text('字号 ${_settings.fontSize.round()} · '
            '字重 ${_settings.fontWeight} · 行距 ${_settings.lineHeight.toStringAsFixed(1)}'),
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
              _changeFontWeight(100);
            },
            child: const Text('加粗'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _changeFontWeight(-100);
            },
            child: const Text('变细'),
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
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _changeParagraphSpacing(4);
            },
            child: const Text('增大段距'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _changeParagraphSpacing(-4);
            },
            child: const Text('减小段距'),
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

  void _showSettings() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('阅读设置'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showThemePicker();
            },
            child: const Text('主题'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showAnimationPicker();
            },
            child: const Text('翻页动画'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _changeMargin(10);
            },
            child: const Text('增大边距'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _changeMargin(-10);
            },
            child: const Text('减小边距'),
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
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showThemePicker();
            },
            child: const Text('背景主题'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showAnimationPicker();
            },
            child: const Text('翻页动画'),
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

  void _showThemePicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('背景主题'),
        actions: ReaderTheme.values
            .map((t) => CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _changeTheme(t);
                  },
                  child: Text(t.label),
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

  void _showAnimationPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('翻页动画'),
        actions: PageAnimation.values
            .map((a) => CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _changeAnimation(a);
                  },
                  child: Text(a.label),
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

  void _changeFontWeight(int delta) {
    final v = (_settings.fontWeight + delta).clamp(300, 700);
    _applySettings(_settings.copyWith(fontWeight: v));
  }

  void _changeLineHeight(double delta) {
    final v = (_settings.lineHeight + delta).clamp(1.2, 2.4);
    _applySettings(_settings.copyWith(lineHeight: v));
  }

  void _changeParagraphSpacing(double delta) {
    final v = (_settings.paragraphSpacing + delta).clamp(4.0, 28.0);
    _applySettings(_settings.copyWith(paragraphSpacing: v));
  }

  void _changeMargin(double delta) {
    final v = (_settings.horizontalMargin + delta).clamp(8.0, 48.0);
    _applySettings(_settings.copyWith(horizontalMargin: v));
  }

  void _changeTheme(ReaderTheme theme) {
    _applySettings(_settings.copyWith(theme: theme));
  }

  void _changeAnimation(PageAnimation animation) {
    _applySettings(_settings.copyWith(pageAnimation: animation));
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
