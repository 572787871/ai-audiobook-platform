library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import '../../library/models/book.dart';
import '../../library/pages/book_detail_page.dart';
import '../../library/services/book_repository.dart';
import '../services/reading_settings_service.dart';
import '../engine/reader_controller.dart';
import '../engine/reader_layout.dart';
import '../widgets/slide_reader.dart';
import '../widgets/scroll_reader.dart';
import '../widgets/cover_reader.dart';
import '../widgets/no_anim_reader.dart';
import '../widgets/simulation_reader.dart';
import '../widgets/reader_toolbar.dart';
import 'reader_settings_page.dart';
import 'directory_page.dart';

/// 阅读器（基于 legado-E 架构重写的章节感知引擎）。
///
/// 性能：打开书籍 -> 解析章节 -> 仅分页当前章 -> 缓存 prev/cur/next 三章；
/// 翻页跨章预加载相邻章，远处缓存释放，不对全书一次分页或一次构建 Widget。
///
/// 阅读位置以字符偏移（[Book.lastReadOffset] + [Book.chapterIndex]）保存与恢复，
/// 不依赖页码；字号/边距/屏幕变化后按偏移重排版。
///
/// 翻页模式：连续滚动 / 左右滑动（默认）/ 覆盖；仿真暂关闭。
/// 保留 iOS 左边缘右滑返回（PopScope(canPop:true)，不被 PageView 抢占）。
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
    final layout = _buildLayout(_settings);
    final controller = ReaderController.load(
      fullText: content,
      layout: layout,
      globalOffset: widget.book.lastReadOffset,
    );
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

  TextStyle _textStyle(Color textColor) => TextStyle(
        fontSize: _settings.fontSize,
        fontWeight: FontWeight.values.firstWhere(
          (w) => w.value == _settings.fontWeight,
          orElse: () => FontWeight.normal,
        ),
        fontFamily: _settings.fontFamily == 'system' ? null : _settings.fontFamily,
        height: _settings.lineHeight,
        color: textColor,
      );


  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveProgress();
    _controller?.dispose();
    super.dispose();
  }

  Future<Book> _saveProgress() async {
    if (_controller == null) return widget.book;
    final pos = _controller!.position;
    final updated = widget.book.copyWith(
      lastReadOffset: pos.characterOffset,
      readingProgress: pos.readingProgress,
      chapterIndex: pos.chapterIndex,
      pageIndex: pos.pageIndex,
      readingTimeSec: widget.book.readingTimeSec,
      lastReadAt: DateTime.now(),
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

  void _openDetail() {
    Navigator.of(context)
        .push(
      CupertinoPageRoute(
        builder: (_) => BookDetailPage(
          book: widget.book,
          repository: widget.repository,
          contentLoader: widget.contentLoader,
        ),
      ),
    )
        .then((updated) {
      if (updated != null && updated is Book && mounted) {
        // 详情页可能修改了进度/标题，原地刷新
        _saveProgress();
      }
    });
  }

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
              _showDirectory();
            },
            child: const Text('目录'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _toggleListening();
            },
            child: Text(_listening ? '停止听书' : '开始听书'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ReaderSettingsPage(
          settings: _settings,
          onChanged: (next) async {
            await ReadingSettingsService.instance.save(next);
            final layout = _buildLayout(next);
            setState(() {
              _settings = next;
              final keep = _controller!.currentCharacterOffset;
              _controller!.repaginate(layout);
              _controller!.goToOffset(keep);
            });
          },
        ),
      ),
    );
  }

  void _showDirectory() {
    if (_controller == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => DirectoryPage(
          chapters: _controller!.chapters,
          currentChapterIndex: _controller!.chapterIndex,
          onJump: (globalOffset) {
            _controller!.goToOffset(globalOffset);
            _saveProgress();
            _scheduleSave();
            setState(() {});
          },
        ),
      ),
    );
  }

  void _toggleListening() {
    setState(() => _listening = !_listening);
    final updated = widget.book.copyWith(isListening: _listening);
    _repo.save(updated);
    _saveProgress();
  }

  void _onPageSettled(int globalOffset) {
    _saveProgress();
    _scheduleSave();
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    final colors = _themeColors();
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: CupertinoPageScaffold(
        child: Stack(
          children: [
            Container(key: const Key('reader_pager'), color: colors.background),
            if (_loading || _controller == null)
              const Center(key: Key('reader_loading'), child: CupertinoActivityIndicator())
            else
              _buildBody(colors),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (d) {
                    final w = MediaQuery.of(context).size.width;
                    // 最左 24pt 交给系统返回，不拦截
                    if (d.localPosition.dx < 24) return;
                    if (d.localPosition.dx > w / 3 && d.localPosition.dx < w * 2 / 3) {
                      _toggleToolbar();
                    } else if (d.localPosition.dx >= w * 2 / 3) {
                      if (_controller!.hasNext) {
                        _controller!.moveNext().then((_) {
                          if (mounted) _onPageSettled(_controller!.currentCharacterOffset);
                        });
                      }
                    } else if (d.localPosition.dx >= 24) {
                      if (_controller!.hasPrev) {
                        _controller!.movePrevious().then((_) {
                          if (mounted) _onPageSettled(_controller!.currentCharacterOffset);
                        });
                      }
                    }
                  },
                ),
              ),
            if (_showToolbar) _buildTopBar(colors),
            if (_showToolbar) _buildBottomToolbar(colors),
          ],
        ),
      ),
    );
  }

  ({Color background, Color text}) _themeColors() {
    switch (_settings.theme) {
      case ReaderTheme.day:
        return (background: CupertinoColors.white, text: CupertinoColors.black);
      case ReaderTheme.sepia:
        return (background: const Color(0xFFF5ECD8), text: const Color(0xFF3A2E1A));
      case ReaderTheme.dark:
        return (background: const Color(0xFF1A1A1A), text: const Color(0xFFD0D0D0));
      case ReaderTheme.night:
        return (background: const Color(0xFF000000), text: const Color(0xFF888888));
    }
  }

  Widget _buildTopBar(({Color background, Color text}) colors) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: colors.background,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: _handleBack,
                child: const KeyedSubtree(key: Key('reader_back'), child: Icon(CupertinoIcons.back, size: 26)),
              ),
              Expanded(
                child: Text(
                  widget.book.title,
                  style: TextStyle(color: colors.text, fontSize: 17, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: _showMore,
                child: const Icon(CupertinoIcons.ellipsis, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(({Color background, Color text}) colors) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ReaderToolbar(
        controller: _controller!,
        settings: _settings,
        listening: _listening,
        onOpenSettings: () => _showSettings(context),
        onToggleListening: _toggleListening,
      ),
    );
  }

  Widget _buildBody(({Color background, Color text}) colors) {
    final ctrl = _controller!;
    final style = _textStyle(colors.text);
    switch (_settings.pageAnimation) {
      case PageAnimation.none:
        return NoAnimReader(
          controller: ctrl,
          textStyle: style,
          textColor: colors.text,
          onPageSettled: _onPageSettled,
        );
      case PageAnimation.slide:
        return SlideReader(
          controller: ctrl,
          textStyle: style,
          textColor: colors.text,
          onPageSettled: _onPageSettled,
        );
      case PageAnimation.cover:
        return CoverReader(
          controller: ctrl,
          textStyle: style,
          textColor: colors.text,
          onPageSettled: _onPageSettled,
        );
      case PageAnimation.scroll:
        return ScrollReader(
          controller: ctrl,
          textStyle: style,
          textColor: colors.text,
        );
      case PageAnimation.curl:
        return SimulationReader(
          controller: ctrl,
          textStyle: style,
          textColor: colors.text,
          onPageSettled: _onPageSettled,
        );
    }
  }
}
