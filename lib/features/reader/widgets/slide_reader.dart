library;

import 'package:flutter/cupertino.dart';
import '../engine/reader_controller.dart';
import '../engine/reader_page_model.dart';
import 'page_text.dart';

/// 左右滑动翻页（默认且当前唯一开放的模式）。
///
/// 设计（稳定、顺滑、贴近成熟阅读器）：
///  - 自绘三页轮播：[上一页, 当前页, 下一页]，手指拖动直接跟手位移（0..1）；
///  - 翻页阈值取 0.2（远小于系统 PageView 的 0.5），小幅滑动也能翻页，杜绝“滑了不动”；
///  - 松手按阈值/甩动速度决定完成或回弹，完成后用 200ms 动画滑到满屏再提交
///    [ReaderController.moveNext]/[movePrevious]，随后瞬间归零（底层已是目标页），
///    无闪白、无空白、无重复页、无跳变；
///  - 边界（首章首页/末章末页）回弹到当前页，绝不渲染空页兜底；
///  - 跨章由 [ReaderController] 统一处理，翻页动画结束即进入下一章第一页。
/// 不依赖 PageView 的 50% 吸附，真机滑动稳定。
class SlideReader extends StatefulWidget {
  final ReaderController controller;
  final TextStyle textStyle;
  final Color textColor;
  final double firstLineIndentChars;
  final void Function(int globalOffset) onPageSettled;

  const SlideReader({
    super.key,
    required this.controller,
    required this.textStyle,
    required this.textColor,
    required this.firstLineIndentChars,
    required this.onPageSettled,
  });

  @override
  State<SlideReader> createState() => _SlideReaderState();
}

class _SlideReaderState extends State<SlideReader>
    with SingleTickerProviderStateMixin {
  double _t = 0.0; // 翻页进度：<0 向左揭下一页，>0 向右揭上一页，绝对值 0..1
  late final AnimationController _anim;
  late Animation<double> _tween;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _tween = _anim.drive(Tween<double>(begin: 0, end: 0));
    _anim.addListener(_onTick);
  }

  @override
  void dispose() {
    _anim.removeListener(_onTick);
    _anim.dispose();
    super.dispose();
  }

  void _onTick() {
    _t = _tween.value;
    if (mounted) setState(() {});
  }

  ReaderPageModel get _cur => widget.controller.currentPage;
  ReaderPageModel get _next => widget.controller.nextPage ?? _cur;
  ReaderPageModel get _prev => widget.controller.previousPage ?? _cur;

  void _onDragUpdate(DragUpdateDetails d) {
    if (_animating) return;
    final width = MediaQuery.of(context).size.width;
    setState(() {
      _t = (_t + d.delta.dx / width).clamp(-1.0, 1.0);
    });
  }

  Future<void> _runAnim(double target) {
    _animating = true;
    _tween = _anim.drive(Tween<double>(begin: _t, end: target));
    _anim.reset();
    return _anim.forward(from: 0).then((_) {
      _animating = false;
    });
  }

  // 完成翻页：先滑到满屏（底层已是目标页），再提交并归零，无跳变。
  Future<void> _finish(bool forward) async {
    await _runAnim(forward ? -1.0 : 1.0);
    final c = widget.controller;
    if (forward && c.hasNext) {
      await c.moveNext();
    } else if (!forward && c.hasPrev) {
      await c.movePrevious();
    }
    if (mounted) widget.onPageSettled(c.currentCharacterOffset);
    if (mounted) {
      _t = 0.0;
      setState(() {});
    }
  }

  Future<void> _onDragEnd(DragEndDetails d) async {
    final progress = _t.abs();
    final forward = _t < 0; // 向左拖动 = 下一页
    final fling = d.velocity.pixelsPerSecond.dx.abs() > 400;
    final willSettle = progress > 0.2 || (fling && progress > 0.08);
    if (!willSettle ||
        (forward ? !widget.controller.hasNext : !widget.controller.hasPrev)) {
      // 未过阈值或边界：回弹到 0，绝不渲染空页
      await _runAnim(0.0);
      return;
    }
    await _finish(forward);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final forward = _t < 0; // true: 向左揭下一页
    final target = forward ? _next : _prev;
    final prog = _t.abs();
    final curX = forward ? -prog * width : prog * width;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          // 底层：目标页（上一页/下一页）铺满，当前页在其上随手指滑动
          Positioned.fill(
            child: _PageContent(
              page: target,
              style: widget.textStyle,
              color: widget.textColor,
              firstLineIndentChars: widget.firstLineIndentChars,
            ),
          ),
          // 当前页：随手指位移，覆盖在目标页之上
          Transform.translate(
            offset: Offset(curX, 0),
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: _PageContent(
                page: _cur,
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

class _PageContent extends StatelessWidget {
  final ReaderPageModel page;
  final TextStyle style;
  final Color color;
  final double firstLineIndentChars;
  const _PageContent({
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
