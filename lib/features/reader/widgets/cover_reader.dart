library;

import 'package:flutter/cupertino.dart';
import '../engine/reader_controller.dart';
import '../engine/reader_page_model.dart';

/// 覆盖翻页（稳定版，不使用仿真动画）。
///
/// 手势左滑：下一页从右侧覆盖当前页（FractionalTranslation 跟手）；
/// 手势右滑：当前页向右揭开露出上一页；松手按阈值决定停留或回弹。
class CoverReader extends StatefulWidget {
  final ReaderController controller;
  final TextStyle textStyle;
  final Color textColor;
  final void Function(int globalOffset) onPageSettled;

  const CoverReader({
    super.key,
    required this.controller,
    required this.textStyle,
    required this.textColor,
    required this.onPageSettled,
  });

  @override
  State<CoverReader> createState() => _CoverReaderState();
}

class _CoverReaderState extends State<CoverReader> {
  double _drag = 0.0; // 当前拖拽位移（正=向右揭开上一页）
  bool _dragging = false;

  ReaderPageModel get _cur => widget.controller.currentPage;
  ReaderPageModel get _next => widget.controller.hasNext
      ? widget.controller.peekNext()
      : _cur;
  ReaderPageModel get _prev => widget.controller.hasPrev
      ? widget.controller.peekPrev()
      : _cur;

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragging = true;
      _drag = (_drag + d.delta.dx).clamp(-400.0, 400.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    final width = MediaQuery.of(context).size.width;
    final threshold = width * 0.33;
    final settleNext = _drag <= -threshold && widget.controller.hasNext;
    final settlePrev = _drag >= threshold && widget.controller.hasPrev;
    if (settleNext) {
      widget.controller.next();
    } else if (settlePrev) {
      widget.controller.prev();
    }
    setState(() {
      _dragging = false;
      _drag = 0.0;
    });
    widget.onPageSettled(widget.controller.currentCharacterOffset);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cur = _cur;
    final overlay = _drag < 0 ? _next : _prev;
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        children: [
          _PageText(page: cur, style: widget.textStyle, color: widget.textColor),
          if (_dragging)
            FractionalTranslation(
              translation: Offset(_drag / width, 0),
              child: Container(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                child: _PageText(
                  page: overlay,
                  style: widget.textStyle,
                  color: widget.textColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PageText extends StatelessWidget {
  final ReaderPageModel page;
  final TextStyle style;
  final Color color;
  const _PageText({required this.page, required this.style, required this.color});

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
