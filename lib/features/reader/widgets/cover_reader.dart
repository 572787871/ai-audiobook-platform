library;

import 'package:flutter/cupertino.dart';
import '../engine/reader_controller.dart';
import '../engine/reader_page_model.dart';
import 'page_text.dart';

/// 覆盖翻页（稳定版，不使用仿真动画）。
///
/// - 手势左滑：下一页从右侧覆盖当前页（FractionalTranslation 跟手）；
/// - 手势右滑：当前页向右揭开露出上一页；
/// 松手按阈值决定停留或回弹。跨章节通过 [ReaderController.moveNext] /
/// [ReaderController.movePrevious] 统一处理，动画完成后才修改页码。
class CoverReader extends StatefulWidget {
  final ReaderController controller;
  final TextStyle textStyle;
  final Color textColor;
  final double firstLineIndentChars;
  final void Function(int globalOffset) onPageSettled;

  const CoverReader({
    super.key,
    required this.controller,
    required this.textStyle,
    required this.textColor,
    required this.firstLineIndentChars,
    required this.onPageSettled,
  });

  @override
  State<CoverReader> createState() => _CoverReaderState();
}

class _CoverReaderState extends State<CoverReader> {
  double _drag = 0.0; // 当前拖拽位移（正=向右揭开上一页）
  bool _dragging = false;

  ReaderPageModel get _cur => widget.controller.currentPage;
  ReaderPageModel get _next =>
      widget.controller.nextPage ?? widget.controller.currentPage;
  ReaderPageModel get _prev =>
      widget.controller.previousPage ?? widget.controller.currentPage;

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragging = true;
      _drag = (_drag + d.delta.dx).clamp(-400.0, 400.0);
    });
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails d) async {
    final width = MediaQuery.of(context).size.width;
    final threshold = width * 0.33;
    final settleNext = _drag <= -threshold && widget.controller.hasNext;
    final settlePrev = _drag >= threshold && widget.controller.hasPrev;
    // 先回弹，避免空白闪现
    setState(() {
      _dragging = false;
      _drag = 0.0;
    });
    if (settleNext) {
      await widget.controller.moveNext();
    } else if (settlePrev) {
      await widget.controller.movePrevious();
    }
    if (mounted) widget.onPageSettled(widget.controller.currentCharacterOffset);
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
          _PageText(page: cur, style: widget.textStyle, color: widget.textColor, firstLineIndentChars: widget.firstLineIndentChars),
          if (_dragging)
            FractionalTranslation(
              translation: Offset(_drag / width, 0),
              child: Container(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                child: _PageText(
                  page: overlay,
                  style: widget.textStyle,
                  color: widget.textColor,
                  firstLineIndentChars: widget.firstLineIndentChars,
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
  final double firstLineIndentChars;
  const _PageText({
    required this.page,
    required this.style,
    required this.color,
    required this.firstLineIndentChars,
  });

  @override
  Widget build(BuildContext context) {
    return buildPageText(
      text: page.text,
      style: style.copyWith(color: color),
      firstLineIndentChars: firstLineIndentChars,
    );
  }
}
