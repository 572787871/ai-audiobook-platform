import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import '../../library/models/book.dart';
import '../../library/pages/book_detail_page.dart';
import '../../library/services/book_repository.dart';
import '../services/reading_settings_service.dart';
import '../engine/reader_controller.dart';
import '../engine/reader_document.dart';
import '../engine/reader_engine.dart';
import '../engine/reader_layout.dart';
import '../engine/reader_page_model.dart';

/// 阅读器（Phase 3 重构）：基于 [ReaderController] 引擎驱动。
///
/// - 连续滚动 / PageView 左右翻页 / 覆盖翻页三种模式，默认 PageView。
/// - 每一页是真正独立的数据（[ReaderPageModel]），逐页用独立 Text 渲染，
///   禁止整本裁剪、禁止两页共用一个 Text、禁止 Transform 对全文动画。
/// - 阅读位置以字符偏移（[Book.lastReadOffset]）保存与恢复，不依赖页码。
/// - 保留 iOS 左边缘右滑返回（PopScope(canPop:true)，不被 PageView 抢占）。
class ReaderPage extends StatefulWidget {
  final Book book;
  final BookRepositoryBase repository;
  final Future<String> Function(Book book)? contentLoader;

  const ReaderPage({
    super.key,
    required this.book,
    required this.repository,
    this.contentLoader,
  });

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  BookRepositoryBase get _repo => widget.repository;

  ReaderController? _controller;
  ReadingSettings _settings = const ReadingSettings();
  bool _loading = true;
  bool _showToolbar = false;
  Timer? _saveTimer;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _listening = widget.book.isListening;
    _load();
  }

  Future<void> _load() async {
    _settings = await ReadingSettingsService.instance.get();
    final loader = widget.contentLoader;
    final content = loader != null
        ? await loader(widget.book)
        : await File(widget.book.contentPath ?? '').readAsString();
    if (!mounted) return;
    final doc = ReaderDocument.fromContent(content, firstLineIndent: 2);
    final layout = _buildLayout(_settings);
    final engine = ReaderEngine(doc, layout);
    final controller = ReaderController(engine: engine);
    // 根据字符偏移恢复位置（不依赖页码）
    controller.goToOffset(widget.book.lastReadOffset);
    setState(() {
      _controller = controller;
      _loading = false;
    });
  }

  ReaderLayout _buildLayout(ReadingSettings s) {
    final size = MediaQuery.of(context).size;
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    return ReaderLayout(
      fontSize: s.fontSize,
      fontWeight: FontWeight.values.firstWhere(
        (w) => w.value == s.fontWeight,
        orElse: () => FontWeight.normal,
      ),
      fontFamily: s.fontFamily == 'system' ? null : s.fontFamily,
      lineHeight: s.lineHeight,
      paragraphSpacing: s.paragraphSpacing,
      horizontalMargin: s.horizontalMargin,
      verticalMargin: 16 + top,
      pageWidth: size.width,
      pageHeight: size.height - bottom,
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveProgress();
    super.dispose();
  }

  Future<Book> _saveProgress() async {
    if (_controller == null) return widget.book;
    final pos = _controller!.position;
    final updated = widget.book.copyWith(
      lastReadOffset: pos.characterOffset,
      readingProgress: pos.readingProgress,
      chapterIndex: pos.chapterIndex,
      updatedAt: DateTime.now(),
    );
    await _repo.save(updated);
    return updated;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _saveProgress);
  }

  Future<void> _handleBack() async {
    final updated = await _saveProgress();
    if (mounted) Navigator.of(context).pop(updated);
  }

  void _toggleToolbar() => setState(() => _showToolbar = !_showToolbar);

  void _showMore() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(widget.book.title),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openDetail();
            },
            child: const Text('书籍详情'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _toggleListening();
            },
            child: Text(_listening ? '停止听书' : '开始听书'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _confirmDelete();
            },
            child: const Text('删除'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _openDetail() async {
    final updated = await _saveProgress();
    if (!mounted) return;
    final result = await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BookDetailPage(book: updated, repository: widget.repository),
      ),
    );
    if (result is Book) {
      // 详情页可能修改了进度/标题，返回后应用
      setState(() {});
    }
  }

  Future<void> _toggleListening() async {
    setState(() => _listening = !_listening);
    await _repo.save(widget.book.copyWith(isListening: _listening));
  }

  Future<void> _confirmDelete() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除本书'),
        content: const Text('确定从书库删除？此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.delete(widget.book.id);
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  ({Color background, Color text}) _bgColors() {
    switch (_settings.theme) {
      case ReaderTheme.day:
        return (background: const Color(0xFFF7F7F7), text: const Color(0xFF1A1A1A));
      case ReaderTheme.sepia:
        return (background: const Color(0xFFF5ECD8), text: const Color(0xFF4A3F2E));
      case ReaderTheme.dark:
        return (background: const Color(0xFF1C1C1E), text: const Color(0xFFD6D6D6));
      case ReaderTheme.night:
        return (background: const Color(0xFF000000), text: const Color(0xFF9A9A9A));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _bgColors();
    return PopScope(
      canPop: true,
      child: CupertinoPageScaffold(
        backgroundColor: colors.background,
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
          child: _loading || _controller == null
              ? const Center(child: CupertinoActivityIndicator())
              : Stack(
                  children: [
                    KeyedSubtree(
                      key: ValueKey(_settings.pageAnimation),
                      child: _buildBody(colors),
                    ),
                    if (_showToolbar) _buildBottomToolbar(colors),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBody(({Color background, Color text}) colors) {
    switch (_settings.pageAnimation) {
      case PageAnimation.none:
        return _ScrollReader(
          controller: _controller!,
          settings: _settings,
          colors: colors,
          onToggleToolbar: _toggleToolbar,
        );
      case PageAnimation.cover:
        return _CoverReader(
          controller: _controller!,
          settings: _settings,
          colors: colors,
          onToggleToolbar: _toggleToolbar,
          onPageChanged: (i) {
            _controller!.goToPage(i);
            _saveProgress();
            _scheduleSave();
          },
        );
      case PageAnimation.curl:
        // 拟真翻页暂未接入，回退到 PageView 滑动，避免不稳定。
        return _PageViewReader(
          controller: _controller!,
          settings: _settings,
          colors: colors,
          onToggleToolbar: _toggleToolbar,
          onPageChanged: (i) {
            _controller!.goToPage(i);
            _saveProgress();
            _scheduleSave();
          },
        );
      case PageAnimation.slide:
        return _PageViewReader(
          controller: _controller!,
          settings: _settings,
          colors: colors,
          onToggleToolbar: _toggleToolbar,
          onPageChanged: (i) {
            _controller!.goToPage(i);
            _saveProgress();
            _scheduleSave();
          },
        );
    }
  }

  Widget _buildBottomToolbar(({Color background, Color text}) colors) {
    final progress = _controller!.position.readingProgress;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: colors.background.withValues(alpha: 0.96),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showSettings(colors),
                child: const Icon(CupertinoIcons.slider_horizontal_3, size: 24),
              ),
              const Spacer(),
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: colors.text)),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _toggleListening,
                child: Icon(
                  _listening ? CupertinoIcons.pause : CupertinoIcons.volume_up,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings(({Color background, Color text}) colors) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _ReaderSettingsSheet(
        settings: _settings,
        onChanged: (next) async {
          await ReadingSettingsService.instance.save(next);
          final layout = _buildLayout(next);
          final engine = ReaderEngine(_controller!.engine.document, layout);
          final keep = _controller!.currentCharacterOffset;
          setState(() {
            _settings = next;
            _controller = ReaderController(engine: engine);
            _controller!.goToOffset(keep);
          });
        },
      ),
    );
  }
}

/// 阅读设置底部弹窗：字体/字号/字重/行距/段距/边距/主题/翻页方式，全部实时生效。
class _ReaderSettingsSheet extends StatefulWidget {
  final ReadingSettings settings;
  final void Function(ReadingSettings) onChanged;
  const _ReaderSettingsSheet({required this.settings, required this.onChanged});

  @override
  State<_ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<_ReaderSettingsSheet> {
  late ReadingSettings _s;

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
  }

  void _update(ReadingSettings next) {
    _s = next;
    widget.onChanged(next);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themes = ReaderTheme.values;
    final animations = const [PageAnimation.none, PageAnimation.slide, PageAnimation.cover];
    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('字号'),
                CupertinoButton(onPressed: () => _update(_s.copyWith(fontSize: (_s.fontSize - 1).clamp(12, 36))), child: const Icon(CupertinoIcons.minus)),
                Text(_s.fontSize.toStringAsFixed(0)),
                CupertinoButton(onPressed: () => _update(_s.copyWith(fontSize: (_s.fontSize + 1).clamp(12, 36))), child: const Icon(CupertinoIcons.plus)),
              ],
            ),
            Row(
              children: [
                const Text('行距'),
                CupertinoSlider(value: _s.lineHeight, min: 1.0, max: 2.4, onChanged: (v) => _update(_s.copyWith(lineHeight: v))),
                Text(_s.lineHeight.toStringAsFixed(1)),
              ],
            ),
            Row(
              children: [
                const Text('字重'),
                CupertinoSlider(value: _s.fontWeight.toDouble(), min: 300, max: 700, divisions: 4, onChanged: (v) => _update(_s.copyWith(fontWeight: v.round()))),
              ],
            ),
            Row(
              children: [
                const Text('段距'),
                CupertinoSlider(value: _s.paragraphSpacing, min: 0, max: 32, onChanged: (v) => _update(_s.copyWith(paragraphSpacing: v))),
              ],
            ),
            Row(
              children: [
                const Text('边距'),
                CupertinoSlider(value: _s.horizontalMargin, min: 8, max: 48, onChanged: (v) => _update(_s.copyWith(horizontalMargin: v))),
              ],
            ),
            Wrap(
              spacing: 8,
              children: themes.map((t) => CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _update(_s.copyWith(theme: t)),
                child: Text(t.label, style: TextStyle(fontWeight: _s.theme == t ? FontWeight.bold : FontWeight.normal)),
              )).toList(),
            ),
            Wrap(
              spacing: 8,
              children: animations.map((a) => CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _update(_s.copyWith(pageAnimation: a)),
                child: Text(_animLabel(a), style: TextStyle(fontWeight: _s.pageAnimation == a ? FontWeight.bold : FontWeight.normal)),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _animLabel(PageAnimation a) {
    switch (a) {
      case PageAnimation.none:
        return '滚动';
      case PageAnimation.slide:
        return '滑动';
      case PageAnimation.cover:
        return '覆盖';
      case PageAnimation.curl:
        return '拟真';
    }
  }
}

/// 连续滚动阅读：所有页文本拼接为单个可滚动列，每页仍是独立 Text 单元。
class _ScrollReader extends StatelessWidget {
  final ReaderController controller;
  final ReadingSettings settings;
  final ({Color background, Color text}) colors;
  final VoidCallback onToggleToolbar;

  const _ScrollReader({
    required this.controller,
    required this.settings,
    required this.colors,
    required this.onToggleToolbar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleToolbar,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: settings.horizontalMargin, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final page in controller.pages)
              _PageText(page: page, settings: settings, colors: colors),
          ],
        ),
      ),
    );
  }
}

/// PageView 左右翻页（默认模式）：每页独立 Widget，无重叠/重复绘制。
class _PageViewReader extends StatelessWidget {
  final ReaderController controller;
  final ReadingSettings settings;
  final ({Color background, Color text}) colors;
  final VoidCallback onToggleToolbar;
  final void Function(int) onPageChanged;

  const _PageViewReader({
    required this.controller,
    required this.settings,
    required this.colors,
    required this.onToggleToolbar,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      key: const Key('reader_pager'),
      controller: PageController(initialPage: controller.pageIndex),
      itemCount: controller.pageCount,
      onPageChanged: onPageChanged,
      itemBuilder: (_, i) => GestureDetector(
        onTap: onToggleToolbar,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: settings.horizontalMargin, vertical: 16),
          child: _PageText(page: controller.pages[i], settings: settings, colors: colors),
        ),
      ),
    );
  }
}

/// 覆盖翻页：基于拖拽进度做覆盖过渡，每页独立渲染。
class _CoverReader extends StatefulWidget {
  final ReaderController controller;
  final ReadingSettings settings;
  final ({Color background, Color text}) colors;
  final VoidCallback onToggleToolbar;
  final void Function(int) onPageChanged;

  const _CoverReader({
    required this.controller,
    required this.settings,
    required this.colors,
    required this.onToggleToolbar,
    required this.onPageChanged,
  });

  @override
  State<_CoverReader> createState() => _CoverReaderState();
}

class _CoverReaderState extends State<_CoverReader> {
  late int _index;
  double _drag = 0.0; // 0..1 拖拽进度
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _index = widget.controller.pageIndex;
  }

  void _commit(bool forward) {
    if (forward && widget.controller.canNext) {
      widget.controller.next();
      widget.onPageChanged(widget.controller.pageIndex);
    } else if (!forward && widget.controller.canPrev) {
      widget.controller.prev();
      widget.onPageChanged(widget.controller.pageIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.controller.pages;
    final current = pages[_index.clamp(0, pages.length - 1)];
    final target = (widget.controller.canNext && _drag > 0) || (widget.controller.canPrev && _drag < 0)
        ? pages[(_index + (_drag > 0 ? 1 : -1)).clamp(0, pages.length - 1)]
        : current;
    final offset = _drag * MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: widget.onToggleToolbar,
      onHorizontalDragUpdate: (d) {
        if (d.delta.dx == 0) return;
        setState(() {
          _dragging = true;
          _drag -= d.delta.dx / MediaQuery.of(context).size.width;
          _drag = _drag.clamp(-1.0, 1.0);
        });
      },
      onHorizontalDragEnd: (_) {
        final forward = _drag > 0.33;
        final backward = _drag < -0.33;
        if (forward) _commit(true);
        if (backward) _commit(false);
        setState(() {
          _dragging = false;
          _drag = 0.0;
          _index = widget.controller.pageIndex;
        });
      },
      child: Stack(
        children: [
          _PageText(page: current, settings: widget.settings, colors: widget.colors),
          if (_dragging)
            Transform.translate(
              offset: Offset(-offset, 0),
              child: Container(
                color: widget.colors.background,
                child: _PageText(page: target, settings: widget.settings, colors: widget.colors),
              ),
            ),
        ],
      ),
    );
  }
}

/// 单页文本：真正独立的渲染单元。每页一个 Text，不共享、不裁剪全文。
class _PageText extends StatelessWidget {
  final ReaderPageModel page;
  final ReadingSettings settings;
  final ({Color background, Color text}) colors;

  const _PageText({required this.page, required this.settings, required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        page.text,
        style: TextStyle(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          fontWeight: FontWeight.values.firstWhere(
            (w) => w.value == settings.fontWeight,
            orElse: () => FontWeight.normal,
          ),
          color: colors.text,
          fontFamily: settings.fontFamily == 'system' ? null : settings.fontFamily,
        ),
      ),
    );
  }
}
