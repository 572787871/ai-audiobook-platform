library;

import 'package:flutter/cupertino.dart';
import '../engine/reader_controller.dart';
import '../engine/reader_page_model.dart';

/// 左右滑动翻页（默认）。每页独立 Text，不重叠、不重复。
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
  int _lastChapter = -1;
  int _lastPage = -1;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    _pageController = PageController(
      initialPage: widget.controller.pageIndex,
    );
    _lastChapter = widget.controller.chapterIndex;
    _lastPage = widget.controller.pageIndex;
  }

  @override
  void didUpdateWidget(covariant SlideReader old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) _sync();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPage(int index) {
    // index 是 PageView 当前页（章内页）；若跨章由 controller.next/prev 维护
    if (index == _lastPage) return;
    _lastPage = index;
    widget.controller.goToChapterPage(_lastChapter, index);
    widget.onPageSettled(widget.controller.currentCharacterOffset);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.controller.pageCount;
    return PageView.builder(
      controller: _pageController,
      itemCount: count,
      onPageChanged: _onPage,
      itemBuilder: (_, i) {
        final page = widget.controller.pageAtChapterPage(_lastChapter, i);
        return _PageContent(page: page, style: widget.textStyle, color: widget.textColor);
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
