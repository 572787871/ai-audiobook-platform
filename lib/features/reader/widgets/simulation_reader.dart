library;

import 'package:flutter/cupertino.dart';
import '../engine/reader_controller.dart';
import '../engine/reader_page_model.dart';

/// 仿真翻页完成阈值：拖拽进度（占屏宽比例）超过此值即完成翻页，否则回弹。
const double kCurlThreshold = 0.4;

/// 模拟纸张翻页（仿真）：右页向左拖动进入下一页，左页向右拖动返回上一页。
///
/// 视觉：拖动时下一页（或上一页）从边缘以"卷曲"形式覆盖，带动态阴影与纸张
/// 背面；跟手移动，未达到阈值回弹，超过阈值（或快速甩动）完成翻页。
/// 数据始终来自 [ReaderController.previousPage]/[currentPage]/[nextPage]，
/// 动画完成后才调用 [ReaderController.moveNext]/[movePrevious]。
class SimulationReader extends StatefulWidget {
  final ReaderController controller;
  final TextStyle textStyle;
  final Color textColor;
  final void Function(int globalOffset) onPageSettled;

  const SimulationReader({
    super.key,
    required this.controller,
    required this.textStyle,
    required this.textColor,
    required this.onPageSettled,
  });

  @override
  State<SimulationReader> createState() => _SimulationReaderState();
}

class _SimulationReaderState extends State<SimulationReader> {
  double _t = 0.0; // 翻页进度 0..1（>0 向左翻下一页，<0 向右翻上一页）
  bool _dragging = false;

  ReaderPageModel get _cur => widget.controller.currentPage;

  // 翻向"下一页"时显示的页（从右向左揭开）
  ReaderPageModel get _next => widget.controller.nextPage ?? _cur;
  // 翻向"上一页"时显示的页（从左向右揭开背面）
  ReaderPageModel get _prev => widget.controller.previousPage ?? _cur;

  void _onDragUpdate(DragUpdateDetails d) {
    final width = MediaQuery.of(context).size.width;
    setState(() {
      _dragging = true;
      _t = (_t + d.delta.dx / width).clamp(-1.0, 1.0);
    });
  }

  Future<void> _onDragEnd(DragEndDetails d) async {
    const threshold = kCurlThreshold;
    final fling = d.velocity.pixelsPerSecond.dx.abs() > 300;
    final forward = _t < 0; // 向左拖动 = 下一页
    final settle = _t.abs() > threshold || (fling && _t.abs() > 0.15);
    // 先回弹到 0
    setState(() {
      _dragging = false;
      _t = 0.0;
    });
    if (settle) {
      if (forward && widget.controller.hasNext) {
        await widget.controller.moveNext();
      } else if (!forward && widget.controller.hasPrev) {
        await widget.controller.movePrevious();
      }
      if (mounted) widget.onPageSettled(widget.controller.currentCharacterOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = _cur;
    final flippingNext = _t < 0; // 向左揭开下一页
    final overlayPage = flippingNext ? _next : _prev;
    final progress = _t.abs();

    final paper = CupertinoColors.systemBackground.resolveFrom(context);

    // 翻起页：从边缘进入，带卷曲倾斜与阴影
    final flip = Transform(
      alignment: flippingNext ? Alignment.centerRight : Alignment.centerLeft,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(flippingNext ? progress * 0.6 : -progress * 0.6),
      child: Container(
        color: paper,
        child: _PageText(page: overlayPage, style: widget.textStyle, color: widget.textColor),
      ),
    );

    // 阴影随进度加深
    final shadow = Container(
      color: CupertinoColors.black.withValues(alpha: 0.25 * progress),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          _PageText(page: cur, style: widget.textStyle, color: widget.textColor),
          // 纸张背面（暗化）
          if (_dragging && progress > 0.001)
            Positioned.fill(child: Container(color: paper)),
          if (_dragging && progress > 0.001)
            FractionalTranslation(
              translation: Offset(flippingNext ? 1.0 - progress : -(1.0 - progress), 0),
              child: Stack(
                children: [
                  flip,
                  // 卷曲边缘阴影
                  if (flippingNext)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 40,
                      child: shadow,
                    )
                  else
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 40,
                      child: shadow,
                    ),
                ],
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
