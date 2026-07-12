library;

import 'package:flutter/cupertino.dart';
import '../engine/reader_controller.dart';
import '../engine/reader_page_model.dart';
import 'page_text.dart';

/// 仿真翻页完成阈值：拖拽进度（占屏宽比例）超过此值即完成翻页，否则回弹。
const double kCurlThreshold = 0.4;

/// 翻页动画时长（与全局 180~220ms 沉浸动效一致）。
const Duration kCurlAnimDuration = Duration(milliseconds: 220);

/// 模拟纸张翻页（仿真）：右页向左拖动进入下一页，左页向右拖动返回上一页。
///
/// 视觉（接近 legado-E 仿真）：
///  - ① 页面卷曲：被翻起的是当前页的背面，带纸张质感与渐变阴影；
///  - ② 手指实时跟随：拖动进度 _t 每帧跟随手指，下一页从对侧同步露出；
///  - ③ 阴影变化：折痕处有底层阴影、纸张背面阴影与高光线，均随进度加深；
///  - ④ 背面颜色：翻起页显示纸张背面（暗化渐变），非透明/白色，杜绝闪白；
///  - ⑤ 回弹动画：未过阈值时动画回弹到 0，绝不渲染空页；
///  - ⑥ 快速甩动：松手时速度足够大即完成翻页；
///  - ⑦ 半页取消 / ⑧ 半页完成：以 kCurlThreshold 为界；
///  - ⑨ 下一章第一页 / ⑩ 上一章最后一页：跨章由 [ReaderController] 统一处理。
/// 完成翻页时先动画到满卷（_t→±1，底层已是目标页），再 moveNext/movePrevious
/// 并立即把 _t 归零，视觉连续、无整页突跳、无闪白。
class SimulationReader extends StatefulWidget {
  final ReaderController controller;
  final TextStyle textStyle;
  final Color textColor;
  final double firstLineIndentChars;
  final void Function(int globalOffset) onPageSettled;

  const SimulationReader({
    super.key,
    required this.controller,
    required this.textStyle,
    required this.textColor,
    required this.firstLineIndentChars,
    required this.onPageSettled,
  });

  @override
  State<SimulationReader> createState() => _SimulationReaderState();
}

class _SimulationReaderState extends State<SimulationReader>
    with SingleTickerProviderStateMixin {
  double _t = 0.0; // 翻页进度：<0 向左揭下一页，>0 向右揭上一页，绝对值 0..1
  late final AnimationController _curlAnim;
  late Animation<double> _tween;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _curlAnim = AnimationController(vsync: this, duration: kCurlAnimDuration);
    _tween = _curlAnim.drive(Tween<double>(begin: 0, end: 0));
    _curlAnim.addListener(_onAnimTick);
  }

  @override
  void dispose() {
    _curlAnim.removeListener(_onAnimTick);
    _curlAnim.dispose();
    super.dispose();
  }

  void _onAnimTick() {
    _t = _tween.value;
    if (mounted) setState(() {});
  }

  ReaderPageModel get _cur => widget.controller.currentPage;
  // 翻向"下一页"时底层露出的页（从右向左揭开）
  ReaderPageModel get _next => widget.controller.nextPage ?? _cur;
  // 翻向"上一页"时底层露出的页（从左向右揭开背面）
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
    _tween = _curlAnim.drive(Tween<double>(begin: _t, end: target));
    _curlAnim.reset();
    return _curlAnim.forward(from: 0).then((_) {
      _animating = false;
    });
  }

  // 完成翻页：先动画到满卷，底层已是目标页，再移动并归零，视觉无缝。
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
    final fling = d.velocity.pixelsPerSecond.dx.abs() > 500;
    final willSettle = progress > kCurlThreshold || (fling && progress > 0.12);
    if (!willSettle || (forward ? !widget.controller.hasNext : !widget.controller.hasPrev)) {
      // ⑤ 回弹：未过阈值或已到边界，动画回弹到 0，绝不渲染空页
      setState(() {});
      await _runAnim(0.0);
      return;
    }
    setState(() {});
    await _finish(forward);
  }

  @override
  Widget build(BuildContext context) {
    final cur = _cur;
    final forward = _t < 0; // true: 向左揭下一页
    final target = forward ? _next : _prev;
    final progress = _t.abs();
    final paper = CupertinoColors.systemBackground.resolveFrom(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          // 底层：目标页（下一页/上一页）始终铺满，保证卷起过程连续无闪白
          _PageText(
            page: target,
            style: widget.textStyle,
            color: widget.textColor,
            firstLineIndentChars: widget.firstLineIndentChars,
          ),
          // 被翻起的当前页（卷曲层），随进度从边缘卷起
          if (progress > 0.001)
            _CurlStack(
              key: const ValueKey('curl'),
              current: cur,
              style: widget.textStyle,
              color: widget.textColor,
              firstLineIndentChars: widget.firstLineIndentChars,
              progress: progress,
              forward: forward,
              paper: paper,
            ),
        ],
      ),
    );
  }
}

/// 卷曲翻页的可视层：平铺的当前页 + 翻起的纸张背面（渐变阴影）+ 折痕高光 + 底层阴影。
class _CurlStack extends StatelessWidget {
  final ReaderPageModel current;
  final TextStyle style;
  final Color color;
  final double firstLineIndentChars;
  final double progress; // 0..1
  final bool forward;
  final Color paper;

  const _CurlStack({
    super.key,
    required this.current,
    required this.style,
    required this.color,
    required this.firstLineIndentChars,
    required this.progress,
    required this.forward,
    required this.paper,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final reveal = progress * w; // 已露出目标页的宽度
        final flatRect = forward
            ? Rect.fromLTRB(reveal, 0, w, h)
            : Rect.fromLTRB(0, 0, w - reveal, h);
        final leafRect = forward
            ? Rect.fromLTRB(0, 0, reveal, h)
            : Rect.fromLTRB(w - reveal, 0, w, h);

        return Stack(
          children: [
            // ③ 底层阴影：折痕投在目标页上的阴影
            if (reveal > 0.5)
              Positioned(
                left: forward ? reveal - 16 : null,
                right: forward ? null : (w - reveal) - 16,
                top: 0,
                bottom: 0,
                width: 16,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: forward
                        ? const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0x00000000), Color(0x33000000)],
                          )
                        : const LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [Color(0x00000000), Color(0x33000000)],
                          ),
                  ),
                ),
              ),
            // 平铺的当前页（仍可读的部分）
            Positioned.fromRect(
              rect: flatRect,
              child: ClipRect(
                child: _PageText(
                  page: current,
                  style: style,
                  color: color,
                  firstLineIndentChars: firstLineIndentChars,
                ),
              ),
            ),
            // ④ 翻起的纸张背面（真实卷曲：以折痕为对角线裁剪出卷起的三角/矩形，
            // 暗化渐变模拟纸张背面，杜绝闪白）
            if (reveal > 0.5)
              Positioned.fromRect(
                rect: leafRect,
                child: ClipPath(
                  clipper: _LeafClipper(
                    forward: forward,
                    curl: progress,
                    size: Size(leafRect.width, h),
                  ),
                  child: Container(
                    color: paper,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: forward
                            ? const LinearGradient(
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                colors: [Color(0x05000000), Color(0x4D000000)],
                              )
                            : const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Color(0x05000000), Color(0x4D000000)],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            // ③ 折痕高光线
            if (reveal > 0.5)
              Positioned(
                left: forward ? reveal - 1 : null,
                right: forward ? null : (w - reveal) - 1,
                top: 0,
                bottom: 0,
                width: 1.5,
                child: Container(color: CupertinoColors.white.withValues(alpha: 0.5)),
              ),
          ],
        );
      },
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

/// 卷曲叶片裁剪：以"折痕"为曲线，裁出被翻起的纸张背面区域。
/// forward（向左揭下一页）时叶片在左侧 [0,reveal]，折痕从右上凹向叶片内侧；
/// backward 时叶片在右侧 [w-reveal,w]，对称。curl 越大折痕越弯，模拟真实卷起。
class _LeafClipper extends CustomClipper<Path> {
  final bool forward;
  final double curl; // 0..1
  final Size size;

  const _LeafClipper({required this.forward, required this.curl, required this.size});

  @override
  Path getClip(Size s) {
    final w = s.width;
    final h = s.height;
    final bend = (1 - curl) * h * 0.25; // 越接近完成，折痕越平
    final p = Path();
    if (forward) {
      // 叶片矩形 [0,0,w,h]，折痕为从 (w,0) 到 (0,h) 的曲线，向叶片内凹
      p.moveTo(0, 0);
      p.lineTo(w, 0);
      p.quadraticBezierTo(w - bend, h * 0.5, 0, h);
      p.close();
    } else {
      // 叶片矩形 [0,0,w,h]，折痕从 (0,0) 到 (w,h) 曲线
      p.moveTo(w, 0);
      p.lineTo(0, 0);
      p.quadraticBezierTo(bend, h * 0.5, w, h);
      p.close();
    }
    return p;
  }

  @override
  bool shouldReclip(covariant _LeafClipper old) =>
      old.forward != forward || old.curl != curl || old.size != size;
}
