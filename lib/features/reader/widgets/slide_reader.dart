library;

import 'package:flutter/cupertino.dart';
import 'dart:developer';
import '../engine/reader_controller.dart';
import '../engine/reader_page_model.dart';

/// 左右滑动翻页（默认且当前唯一开放的模式）。
///
/// 设计（修复抖动/闪回/手势失效/边界错乱/跨章节失败/页面重复）：
///  - 固定三页窗口 [上一页, 当前页, 下一页]，PageView 始终停在中间 index=1；
///  - [onPageChanged] 在翻页动画【完全结束】后才会被调用（不是滑动过半），
///    此时才让 [ReaderController] 真正推进，并立即 rebuild 新的 prev/cur/next；
///  - 用无动画的 [PageController.jumpToPage] 重置回中间（内容连续，无视觉跳变）；
///  - [_isTransitioning] 全程加锁：禁止重复 onPageChanged、禁止多次 jumpToPage、
///    禁止 moveNext/movePrevious 与页面状态分离；reset 期间用 IgnorePointer 禁手势；
///  - 真正边界（上一页/下一页为 null）时【回弹】到中间，绝不渲染空页兜底。
class SlideReader extends StatefulWidget {
  final ReaderController controller;
  final TextStyle textStyle;
  final Color textColor;
  final void Function(int globalOffset) onPageSettled;

  const SlideReader({
    super.key,
    required this.controller,
    required this.textStyle,
    required this.textColor,
    required this.onPageSettled,
  });

  @override
  State<SlideReader> createState() => _SlideReaderState();
}

class _SlideReaderState extends State<SlideReader> {
  late PageController _pageController;
  static const int _mid = 1;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _mid);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 三页窗口：[上一页, 当前页, 下一页]。边界处用当前页占位以保证连续，
  // 但占位页不会触发翻页（见 _onPageChanged 的边界回弹）。
  List<ReaderPageModel> _window() {
    final prev = widget.controller.previousPage;
    final cur = widget.controller.currentPage;
    final next = widget.controller.nextPage;
    return [
      prev ?? cur,
      cur,
      next ?? cur,
    ];
  }

  void _logReaderNav({
    required bool goingNext,
    required bool moved,
    required int pageViewIndex,
  }) {
    final c = widget.controller;
    final cur = c.currentPage;
    log('[READER_NAV] mode=slide ch=${c.chapterIndex} page=${c.pageIndex} '
        'start=${cur.startOffset} end=${cur.endOffset} '
        'prevExists=${c.previousPage != null} nextExists=${c.nextPage != null} '
        'action=${goingNext ? "moveNext" : "movePrevious"} moved=$moved '
        'pageViewIndex=$pageViewIndex transitioning=$_isTransitioning');
  }

  // 边界回弹：翻到占位页（真实上下页不存在）时，不移动 controller，
  // 直接动画回到中间，绝不渲染空页。
  Future<void> _snapBack() async {
    await _pageController.animateToPage(
      _mid,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    if (mounted) _isTransitioning = false;
  }

  Future<void> _onPageChanged(int index) async {
    if (_isTransitioning) return;
    if (index == _mid) return;
    _isTransitioning = true;

    final goingNext = index > _mid;
    final c = widget.controller;

    // 边界检查：真实上下页未就绪则不翻页，直接回弹。
    final nextReady = goingNext ? (c.nextPage != null) : (c.previousPage != null);
    if (!nextReady) {
      await _snapBack();
      return;
    }

    // 章节切换：nextPage 已同步就绪（分页在控制器内同步完成并缓存），
    // 这里无需额外等待；_isTransitioning 已防止重叠触发。
    final moved =
        goingNext ? await c.moveNext() : await c.movePrevious();
    _logReaderNav(goingNext: goingNext, moved: moved, pageViewIndex: index);

    if (!moved) {
      await _snapBack();
      return;
    }

    if (mounted) {
      // 1) 先 rebuild 新窗口（prev/cur/next 已随 controller 更新）
      setState(() {});
      // 2) 无动画重置到中间；内容连续，用户在 index2/0 看到的正是新的 cur，无跳变
      _pageController.jumpToPage(_mid);
      // 3) 通知外层保存进度
      widget.onPageSettled(c.currentCharacterOffset);
    }
    if (mounted) _isTransitioning = false;
  }

  @override
  Widget build(BuildContext context) {
    final window = _window();
    return IgnorePointer(
      ignoring: _isTransitioning,
      child: PageView.builder(
        controller: _pageController,
        itemCount: window.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (_, i) {
          return _PageContent(
            page: window[i],
            style: widget.textStyle,
            color: widget.textColor,
          );
        },
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final ReaderPageModel page;
  final TextStyle style;
  final Color color;
  const _PageContent({required this.page, required this.style, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        page.text,
        style: style.copyWith(color: color),
        textAlign: TextAlign.left,
      ),
    );
  }
}
