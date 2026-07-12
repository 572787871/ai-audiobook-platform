library;

import 'package:flutter/cupertino.dart';
import '../engine/reader_controller.dart';
import 'page_text.dart';
import '../engine/reader_page_model.dart';

/// 连续滚动阅读：始终渲染 [prev, cur, next] 三章页拼接为可滚动列，
/// 滚动到当前章边界时由 [ReaderController] 统一切换上一/下一章，并修正
/// scroll offset 保持视觉不跳动。不一次构建全书所有 Widget。
class ScrollReader extends StatefulWidget {
  final ReaderController controller;
  final TextStyle textStyle;
  final Color textColor;
  final double firstLineIndentChars;

  const ScrollReader({
    super.key,
    required this.controller,
    required this.textStyle,
    required this.textColor,
    required this.firstLineIndentChars,
  });

  @override
  State<ScrollReader> createState() => _ScrollReaderState();
}

class _ScrollReaderState extends State<ScrollReader> {
  late ScrollController _scroll;
  final GlobalKey _prevKey = GlobalKey();
  final GlobalKey _curKey = GlobalKey();
  final GlobalKey _nextKey = GlobalKey();
  bool _adjusting = false;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ScrollReader old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _scroll.removeListener(_onScroll);
      _scroll = ScrollController()..addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_adjusting || !_scroll.hasClients) return;
    final pos = _scroll.position;
    final viewportBottom = pos.pixels + pos.viewportDimension;
    final curBox = _curKey.currentContext?.findRenderObject() as RenderBox?;
    if (curBox == null) return;
    final curTop = curBox.localToGlobal(Offset.zero).dy;
    final curBottom = curTop + curBox.size.height;
    final topPad = MediaQuery.of(context).padding.top;
    if (curBottom < topPad + 40 && widget.controller.hasNext) {
      _switchChapter(forward: true);
    } else if (curTop > viewportBottom - 40 && widget.controller.hasPrev) {
      _switchChapter(forward: false);
    }
  }

  Future<void> _switchChapter({required bool forward}) async {
    // 切换前：记录当前章顶部相对视口顶的偏移，用于切换后保持视觉连续
    final curBox = _curKey.currentContext?.findRenderObject() as RenderBox?;
    final viewportTopBefore = _scroll.hasClients
        ? _scroll.position.pixels
        : 0.0;
    final curTopGlobalBefore = _scroll.hasClients && curBox != null
        ? curBox.localToGlobal(Offset.zero).dy + viewportTopBefore
        : 0.0;
    _adjusting = true;
    if (forward) {
      await widget.controller.moveToNextChapter();
    } else {
      await widget.controller.moveToPreviousChapter();
    }
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        _adjusting = false;
        return;
      }
      final newCurBox =
          _curKey.currentContext?.findRenderObject() as RenderBox?;
      if (newCurBox == null) {
        _adjusting = false;
        return;
      }
      // 新当前章顶部相对内容顶部的全局坐标
      final newCurTopGlobal =
          newCurBox.localToGlobal(Offset.zero).dy + _scroll.position.pixels;
      final delta = curTopGlobalBefore - newCurTopGlobal;
      final target = (viewportTopBefore + delta).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.jumpTo(target);
      _adjusting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.controller.threeChapterBlocks;
    Widget buildChapter(List<ReaderPageModel> ps, Key? key) {
      return Container(
        key: key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ps
              .map(
                (p) => _PageText(
                  p: p,
                  style: widget.textStyle,
                  color: widget.textColor,
                  firstLineIndentChars: widget.firstLineIndentChars,
                ),
              )
              .toList(),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (blocks.prev != null) buildChapter(blocks.prev!, _prevKey),
          buildChapter(blocks.cur, _curKey),
          if (blocks.next != null) buildChapter(blocks.next!, _nextKey),
        ],
      ),
    );
  }
}

class _PageText extends StatelessWidget {
  final ReaderPageModel p;
  final TextStyle style;
  final Color color;
  final double firstLineIndentChars;
  const _PageText({
    required this.p,
    required this.style,
    required this.color,
    required this.firstLineIndentChars,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: buildPageText(
        text: p.text,
        style: style.copyWith(color: color),
        firstLineIndentChars: firstLineIndentChars,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
