library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../library/models/book.dart';
import '../../library/pages/book_detail_page.dart';
import '../../library/services/book_repository.dart';
import '../services/reading_settings_service.dart';
import '../engine/reader_controller.dart';
import '../engine/reader_layout.dart';
import '../widgets/slide_reader.dart';
import '../widgets/cover_reader.dart';
import '../widgets/scroll_reader.dart';
import '../widgets/no_anim_reader.dart';
import '../widgets/simulation_reader.dart';
import '../widgets/reader_top_bar.dart';
import '../widgets/reader_bottom_bar.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/reader_spacing_sheet.dart';
import '../widgets/reader_audio_floating_bar.dart';
import '../widgets/reader_progress_bar.dart';
import '../widgets/reader_tap_overlay.dart';
import 'directory_page.dart';

/// 阅读器（基于 legado-E 架构重写的章节感知引擎）。
///
/// 性能：只分页当前章、缓存 prev/cur/next 三章，不对全书一次分页或一次构建 Widget；
/// 正文、工具栏、设置面板分层渲染，工具栏显隐不重新加载正文。
///
/// 默认进入沉浸阅读：顶部/底部栏隐藏，点击屏幕中间淡入淡出（180~220ms）。
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
  final bool _audioModelReady = false; // 本地听书模型（Kokoro）是否已就绪
  bool _autoReading = false;
  Timer? _autoReadTimer;
  // 屏幕方向（横竖屏）：进入时锁定为当前设置，切换实时重排版。
  Orientation _orientation = Orientation.portrait;

  @override
  void initState() {
    super.initState();
    _listening = widget.book.isListening;
    _applyOrientation();
    _load();
  }

  // 横竖屏：按设置锁定方向（自动阅读不影响方向）。
  void _applyOrientation() {
    final landscape = _settings.readingDirection;
    SystemChrome.setPreferredOrientations(
      landscape
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp],
    );
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
      verticalMargin: s.verticalMargin + top,
      pageWidth: size.width,
      pageHeight: size.height - bottom,
      firstLineIndentChars: s.firstLineIndent,
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
    _autoReadTimer?.cancel();
    _saveProgress();
    _controller?.dispose();
    super.dispose();
  }

  Future<Book> _saveProgress() async {
    if (_controller == null) return widget.book;
    final pos = _controller!.position;
    final now = DateTime.now();
    // 阅读时长与最后阅读时间：进入即记录、每次落点累加，恢复时仍可读。
    final readingTimeSec = widget.book.readingTimeSec +
        (now.difference(widget.book.lastReadAt ?? now).inSeconds.clamp(0, 1 << 30));
    final updated = widget.book.copyWith(
      lastReadOffset: pos.characterOffset,
      readingProgress: pos.readingProgress,
      chapterIndex: pos.chapterIndex,
      pageIndex: pos.pageIndex,
      isListening: _listening,
      readingTimeSec: readingTimeSec,
      lastReadAt: now,
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

  // 更多菜单：未实现功能显示真实状态
  void _onRename() => _toast('重命名：功能开发中');
  void _onSearch() => _toast('搜索：功能开发中');
  void _onBookmark() => _toast('书签：功能开发中');
  void _onShare() => _toast('分享：功能开发中');
  // 自动阅读：整页翻页模式下按固定间隔自动翻下一页，到末章末页停止。
  // 真实计时器驱动真实翻页，不伪造进度；仅 paged 模式生效。
  void _toggleAutoRead() {
    if (_autoReading) {
      _stopAutoRead();
      return;
    }
    if (_controller == null) return;
    if (!_controller!.hasNext && _controller!.pageIndex >= _controller!.pageCount - 1) {
      _toast('已是最后一页');
      return;
    }
    setState(() {
      _autoReading = true;
      // 同步持久化开关，供设置面板显示当前状态
      _settings = _settings.copyWith(autoPage: true);
    });
    ReadingSettingsService.instance.save(_settings);
    _scheduleAutoRead();
  }

  void _scheduleAutoRead() {
    _autoReadTimer?.cancel();
    _autoReadTimer = Timer(const Duration(seconds: 3), () async {
      if (!_autoReading || _controller == null || !mounted) return;
      final moved = await _controller!.moveNext();
      if (!moved) {
        _stopAutoRead();
        return;
      }
      _onPageSettled();
      _scheduleAutoRead();
    });
  }

  void _stopAutoRead() {
    _autoReadTimer?.cancel();
    _autoReadTimer = null;
    if (_autoReading && mounted) {
      setState(() {
        _autoReading = false;
        _settings = _settings.copyWith(autoPage: false);
      });
      ReadingSettingsService.instance.save(_settings);
    }
  }
  void _onAutoRead() => _toggleAutoRead();

  void _toast(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(child: const Text('好'), onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

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
      if (updated != null && updated is Book && mounted) _saveProgress();
    });
  }

  void _toggleListening() {
    // 听书接口预留：play/pause/stop/previousSentence/nextSentence/setRate/setVoice。
    // Kokoro 未完成时只切换 UI 显隐并给出真实提示，不伪造播放、不启动假计时器。
    if (!_audioModelReady) {
      _toast('本地听书模型尚未准备');
      return;
    }
    setState(() => _listening = !_listening);
    _saveProgress();
  }

  void _closeListening() {
    setState(() => _listening = false);
    _saveProgress();
  }

  void _onAudioPlayPause() {
    if (!_audioModelReady) {
      _toast('本地听书模型尚未准备');
      return;
    }
    setState(() => _listening = !_listening);
    _saveProgress();
  }


  void _showSettingsSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => ReaderSettingsSheet(
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
        onOpenSpacing: () {
          Navigator.of(ctx).pop();
          showCupertinoModalPopup(
            context: context,
            builder: (sctx) => ReaderSpacingSheet(
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
          );
        },
        onOpenMore: () => _showMoreSettings(),
        onAutoRead: () => _onAutoRead(),
      ),
    );
  }

  void _showMoreSettings() {
    // 更多设置：接口已接（设置项持久化），未实现功能明确标记“暂未开放”。
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('更多设置'),
        message: const Text('以下选项已保存设置，功能暂未开放'),
        actions: [
          CupertinoActionSheetAction(onPressed: () { Navigator.of(ctx).pop(); _toast('自动翻页：暂未开放'); }, child: const Text('自动翻页')),
          CupertinoActionSheetAction(onPressed: () { Navigator.of(ctx).pop(); _toast('屏幕常亮：暂未开放'); }, child: const Text('屏幕常亮')),
          CupertinoActionSheetAction(onPressed: () { Navigator.of(ctx).pop(); _toast('音量键翻页：暂未开放'); }, child: const Text('音量键翻页')),
          CupertinoActionSheetAction(onPressed: () { Navigator.of(ctx).pop(); _toast('简繁转换：暂未开放'); }, child: const Text('简繁转换')),
          CupertinoActionSheetAction(onPressed: () { Navigator.of(ctx).pop(); _toast('阅读方向：暂未开放'); }, child: const Text('阅读方向')),
          CupertinoActionSheetAction(onPressed: () { Navigator.of(ctx).pop(); _toast('状态栏显示：暂未开放'); }, child: const Text('状态栏显示')),
          CupertinoActionSheetAction(onPressed: () { Navigator.of(ctx).pop(); _toast('阅读进度显示：暂未开放'); }, child: const Text('阅读进度显示')),
          CupertinoActionSheetAction(onPressed: () { Navigator.of(ctx).pop(); _toast('章节标题显示：暂未开放'); }, child: const Text('章节标题显示')),
          CupertinoActionSheetAction(onPressed: () { Navigator.of(ctx).pop(); _toast('点击区域设置：暂未开放'); }, child: const Text('点击区域设置')),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
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

  Future<void> _prevChapter() async {
    if (_controller == null) return;
    await _controller!.moveToPreviousChapter();
    _onPageSettled();
  }

  Future<void> _nextChapter() async {
    if (_controller == null) return;
    await _controller!.moveToNextChapter();
    _onPageSettled();
  }

  void _onChapterSliderChanged(double v) {
    if (_controller == null) return;
    final idx = (v * (_controller!.chapterCount - 1)).round().clamp(0, _controller!.chapterCount - 1);
    final start = _controller!.chapters.chapters[idx].start;
    _controller!.goToOffset(start);
    _onPageSettled();
  }

  void _onPageSettled([int offset = 0]) {
    _saveProgress();
    _scheduleSave();
    if (mounted) setState(() {});
  }

  void _toggleNight() async {
    final next = _settings.theme == ReaderTheme.night
        ? _settings.copyWith(
            theme: _settings.nightPreviousTheme ?? ReaderTheme.sepia,
            clearNightPrevious: true,
          )
        : _settings.copyWith(theme: ReaderTheme.night, nightPreviousTheme: _settings.theme);
    await ReadingSettingsService.instance.save(next);
    final layout = _buildLayout(next);
    setState(() {
      _settings = next;
      final keep = _controller!.currentCharacterOffset;
      _controller!.repaginate(layout);
      _controller!.goToOffset(keep);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = _settings.eyeCare
        ? ReaderBackground.green.color
        : _settings.background.color;
    final textColor = _settings.textColor.color;
    // 屏幕方向：进入时按设置锁定，可实时跟随系统切换并重排版。
    final targetOrientation = _settings.readingDirection
        ? Orientation.landscape
        : Orientation.portrait;
    if (_orientation != targetOrientation) _orientation = targetOrientation;
    // 亮度：整体叠一层半透明黑，越暗越压低；夜间/深色模式不叠加以免二次压暗。
    final dim = _settings.brightness >= 1.0
        ? 0.0
        : (1.0 - _settings.brightness).clamp(0.0, 0.7);
    // 背景图片：选中"自定义背景"且已指定本地路径时铺满全屏。
    final bgImage = (_settings.background == ReaderBackground.custom &&
            _settings.backgroundImagePath?.isNotEmpty == true)
        ? _customBgImage
        : null;
    return CupertinoPageScaffold(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: bg,
          child: Stack(
            children: [
              // 背景图片层（自定义背景）：铺满全屏，正文在其上绘制。
              if (bgImage != null)
                Positioned.fill(child: Image.file(bgImage, fit: BoxFit.cover)),
              if (_loading || _controller == null)
                const Center(key: Key('reader_loading'), child: CupertinoActivityIndicator())
              else ...[
                // 正文层（分层渲染，不依赖工具栏状态）
                Positioned.fill(
                  child: Container(key: const Key('reader_pager'), child: _buildBody(textColor)),
                ),
                // 手势层：仅沉浸态启用。左25%上页/中50%显隐/右25%下页；
                // 最左24pt交系统返回。工具栏显示时隐藏，避免抢占返回按钮点击。
                if (!_showToolbar)
                  Positioned.fill(
                    child: ReaderTapOverlay(
                      onTapPrevious: () {
                        if (_controller!.hasPrev) {
                          _controller!.movePrevious().then((_) => _onPageSettled());
                        }
                      },
                      onToggleToolbar: _toggleToolbar,
                      onTapNext: () {
                        if (_controller!.hasNext) {
                          _controller!.moveNext().then((_) => _onPageSettled());
                        }
                      },
                    ),
                  ),
                // 沉浸态进度信息
                if (!_showToolbar && !_loading)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ReaderProgressBar(
                      progress: _controller!.position.readingProgress,
                      rightLabel:
                          '${_controller!.pageIndex + 1} / ${_controller!.pageCount}',
                    ),
                  ),
                // 听书悬浮条（左下角）
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ReaderAudioFloatingBar(
                    listening: _listening,
                    modelReady: _audioModelReady,
                    statusText: _audioModelReady
                        ? (_listening ? '正在朗读…' : '已暂停')
                        : '本地听书模型尚未准备',
                    onPlayPause: _onAudioPlayPause,
                    onClose: _closeListening,
                  ),
                ),
                // 亮度压暗层：半透明黑覆盖全屏，越暗越压低，不影响正文数据。
                if (dim > 0.001)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: CupertinoColors.black.withValues(alpha: dim),
                      ),
                    ),
                  ),
              ],
              // 顶部栏（淡入淡出由 ReaderTopBar 内部背景 AnimatedContainer 承担）。
              // 必须用 Positioned 包裹：ReaderTopBar 是 Stack 中唯一的非定位子节点，
              // 若直接作为非定位子节点会让 Stack 收缩到其高度（~44px），导致所有
              // bottom:0 的栏向上溢出覆盖顶部返回按钮，拦截其命中。
              if (_showToolbar)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ReaderTopBar(
                    bookTitle: widget.book.title,
                    chapterTitle: _controller?.currentChapterTitle,
                    onBack: _handleBack,
                    onListening: _toggleListening,
                    onShare: _onShare,
                    onBookDetail: _openDetail,
                    onRename: _onRename,
                    onSearch: _onSearch,
                    onBookmark: _onBookmark,
                    onDelete: _confirmDelete,
                  ),
                ),
              // 底部栏（淡入淡出）
              if (_showToolbar)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ReaderBottomBar(
                    chapterProgress: _chapterInnerProgress(),
                    chapterPositionLabel:
                        '第 ${_controller!.chapterIndex + 1} / ${_controller!.chapterCount} 章',
                    onPrevChapter: _prevChapter,
                    onNextChapter: _nextChapter,
                    onChapterSliderChanged: _onChapterSliderChanged,
                    onDirectory: _showDirectory,
                    onNight: _toggleNight,
                    onSettings: () => _showSettingsSheet(),
                    onListening: _toggleListening,
                  ),
              ),
            ],
          ),
        ),
    );
  }

  double _chapterInnerProgress() {
    if (_controller == null || _controller!.pageCount <= 1) return 0.0;
    return _controller!.pageIndex / (_controller!.pageCount - 1);
  }

  /// 自定义背景图片（ReaderBackground.custom）。接口预留：测试/默认环境无资源时返回 null。
  File? get _customBgImage {
    final path = _settings.backgroundImagePath;
    if (path == null || path.isEmpty) return null;
    final f = File(path);
    return f.existsSync() ? f : null;
  }

  void _confirmDelete() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定删除《${widget.book.title}》？此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(child: const Text('取消'), onPressed: () => Navigator.of(ctx).pop()),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _repo.delete(widget.book.id);
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Color textColor) {
    final ctrl = _controller!;
    final style = _textStyle(textColor);
    switch (_settings.pageAnimation) {
      case PageAnimation.none:
        return NoAnimReader(
          controller: ctrl,
          textStyle: style,
          textColor: textColor,
          firstLineIndentChars: _settings.firstLineIndent,
          onPageSettled: _onPageSettled,
        );
      case PageAnimation.slide:
        return SlideReader(
          controller: ctrl,
          textStyle: style,
          textColor: textColor,
          firstLineIndentChars: _settings.firstLineIndent,
          onPageSettled: _onPageSettled,
        );
      case PageAnimation.cover:
        return CoverReader(
          controller: ctrl,
          textStyle: style,
          textColor: textColor,
          firstLineIndentChars: _settings.firstLineIndent,
          onPageSettled: _onPageSettled,
        );
      case PageAnimation.scroll:
        return ScrollReader(
          controller: ctrl,
          textStyle: style,
          textColor: textColor,
          firstLineIndentChars: _settings.firstLineIndent,
        );
      case PageAnimation.curl:
        return SimulationReader(
          controller: ctrl,
          textStyle: style,
          textColor: textColor,
          firstLineIndentChars: _settings.firstLineIndent,
          onPageSettled: _onPageSettled,
        );
    }
  }
}
