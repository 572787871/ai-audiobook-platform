library;

import 'package:flutter/cupertino.dart';
import '../engine/reader_controller.dart';
import '../engine/reader_page_model.dart';

/// 左右滑动翻页（默认）。使用三页窗口（上一页/当前页/下一页），
/// 跨章节由 [ReaderController.moveNext] / [ReaderController.movePrevious] 统一处理，
/// UI 始终停留在窗口中间（index=1），翻页后跳回中间，避免各模式自行维护章节。
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

  // 三页窗口：[上一页, 当前页, 下一页]
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

  Future<void> _onPageChanged(int index) async {
    if (index == _mid) return;
    // 先回弹到窗口中间，再让 controller 真正翻页，保持窗口稳定
    if (index > _mid) {
      await widget.controller.moveNext();
    } else {
      await widget.controller.movePrevious();
    }
    if (mounted) {
      _pageController.jumpToPage(_mid);
      widget.onPageSettled(widget.controller.currentCharacterOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final window = _window();
    return PageView.builder(
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
