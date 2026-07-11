import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../../../features/reader/services/reading_settings_service.dart'
    show PageAnimation;

/// 阅读器翻页容器。
///
/// 支持四种翻页模式：
///  - [PageAnimation.none]    直接切页
///  - [PageAnimation.slide]   横向滑动（PageView）
///  - [PageAnimation.cover]   覆盖式（新页面从右滑入盖住旧页）
///  - [PageAnimation.simulation] 拟真纸张翻页（卷曲裁剪 + 阴影 + 背面）
///
/// 手势分区（屏幕宽度比例）：
///  - 最左侧 [edgeWidth] pt：留给 iOS 系统右滑返回，本组件不拦截
///  - 左侧正文区：上一页
///  - 中间区：显示/隐藏工具栏
///  - 右侧正文区：下一页
///  - 拖拽：进入翻页动画（仿真为纸张卷曲）
class ReaderPager extends StatefulWidget {
  final List<Widget> pages;
  final int initialIndex;
  final PageAnimation animation;
  final double edgeWidth;
  final VoidCallback? onToggleToolbar;
  final ValueChanged<int>? onPageChanged;

  const ReaderPager({
    super.key,
    required this.pages,
    this.initialIndex = 0,
    this.animation = PageAnimation.slide,
    this.edgeWidth = 24.0,
    this.onToggleToolbar,
    this.onPageChanged,
  });

  @override
  State<ReaderPager> createState() => _ReaderPagerState();
}

class _ReaderPagerState extends State<ReaderPager> {
  late int _index;
  late PageAnimation _animation;
  late PageController _pageController;
  double _drag = 0.0; // >0 向左翻下一页，<0 向右翻上一页
  bool _dragging = false;
  bool _turnNext = true;
  final double _threshold = 0.33;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, max(0, widget.pages.length - 1));
    _animation = widget.animation;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void didUpdateWidget(covariant ReaderPager old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _animation = widget.animation;
      if (_pageController.hasClients) _pageController.jumpToPage(_index);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int next) {
    if (next < 0 || next >= widget.pages.length) return;
    setState(() => _index = next);
    widget.onPageChanged?.call(next);
  }

  void _next() => _goTo(_index + 1);
  void _prev() => _goTo(_index - 1);

  void _onTapDown(Offset pos, Size size) {
    if (pos.dx <= widget.edgeWidth) return; // 留给系统返回
    final third = size.width / 3;
    if (pos.dx < third) {
      _prev();
    } else if (pos.dx > third * 2) {
      _next();
    } else {
      widget.onToggleToolbar?.call();
    }
  }

  void _onDragStart(DragStartDetails d) {
    if (d.globalPosition.dx <= widget.edgeWidth) return;
    if (_animation == PageAnimation.none || _animation == PageAnimation.slide) return;
    _dragging = true;
    _drag = 0.0;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final delta = -d.primaryDelta! / context.size!.width;
    setState(() {
      _drag = (_drag + delta).clamp(-1.0, 1.0);
      _turnNext = _drag >= 0;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final go = _drag.abs() >= _threshold;
    final next = _turnNext ? _index + 1 : _index - 1;
    if (go && next >= 0 && next < widget.pages.length) _goTo(next);
    setState(() => _drag = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_animation == PageAnimation.none) return _buildNone();
    if (_animation == PageAnimation.slide) return _buildSlide();
    if (_animation == PageAnimation.cover) return _buildCover();
    return _buildSimulation();
  }

  Widget _buildNone() => GestureDetector(
        onTapDown: (d) => _onTapDown(d.localPosition, context.size!),
        child: IndexedStack(index: _index, children: widget.pages),
      );

  Widget _buildSlide() => GestureDetector(
        onTapDown: (d) => _onTapDown(d.localPosition, context.size!),
        child: PageView.builder(
        controller: _pageController,
        onPageChanged: _goTo,
        itemCount: widget.pages.length,
        itemBuilder: (_, i) => widget.pages[i],
        ),
      );

  Widget _buildCover() {
    final current = widget.pages[_index];
    final next = (_index + 1 < widget.pages.length)
        ? widget.pages[_index + 1]
        : const SizedBox.shrink();
    return GestureDetector(
      onTapDown: (d) => _onTapDown(d.localPosition, context.size!),
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          current,
          if (_dragging)
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(-_drag * MediaQuery.of(context).size.width, 0),
                child: next,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSimulation() {
    final current = widget.pages[_index];
    final next = (_index + 1 < widget.pages.length)
        ? widget.pages[_index + 1]
        : const SizedBox.shrink();
    final prev = (_index - 1 >= 0) ? widget.pages[_index - 1] : const SizedBox.shrink();
    return GestureDetector(
      onTapDown: (d) => _onTapDown(d.localPosition, context.size!),
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          // 底层：下一页（向左翻时露出）
          next,
          // 翻转中的当前页（卷曲 + 阴影）
          AnimatedSwitcher(
            duration: Duration.zero,
            child: _dragging
                ? _PageTurn(
                    key: ValueKey(_turnNext),
                    progress: _drag.abs(),
                    turnNext: _turnNext,
                    front: current,
                    back: prev,
                  )
                : current,
          ),
        ],
      ),
    );
  }
}

/// 拟真纸张翻转：以卷曲裁剪表现翻页，叠加阴影与背面。
class _PageTurn extends StatelessWidget {
  final double progress;
  final bool turnNext;
  final Widget front;
  final Widget back;

  const _PageTurn({
    super.key,
    required this.progress,
    required this.turnNext,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return Stack(
      children: [
        if (!turnNext) back,
        ClipPath(
          clipper: _PageCurlClipper(progress: p, turnNext: turnNext),
          child: front,
        ),
        // 卷曲阴影
        if (p > 0.001)
          Positioned.fill(
            child: CustomPaint(
              painter: _CurlShadowPainter(progress: p, turnNext: turnNext),
            ),
          ),
      ],
    );
  }
}

class _PageCurlClipper extends CustomClipper<Path> {
  final double progress;
  final bool turnNext;
  _PageCurlClipper({required this.progress, required this.turnNext});

  @override
  Path getClip(Size size) {
    final p = progress.clamp(0.0, 1.0);
    final path = Path();
    if (turnNext) {
      // 向左翻：右侧卷起，露出左侧已翻部分宽度 = size.width * p
      final cut = size.width * p;
      path.moveTo(0, 0);
      path.lineTo(size.width - cut, 0);
      // 卷边斜边
      path.lineTo(size.width - cut + 24, size.height);
      path.lineTo(0, size.height);
      path.close();
    } else {
      // 向右翻：左缘卷起
      final cut = size.width * p;
      path.moveTo(cut, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(cut - 24, size.height);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _PageCurlClipper old) =>
      old.progress != progress || old.turnNext != turnNext;
}

class _CurlShadowPainter extends CustomPainter {
  final double progress;
  final bool turnNext;
  _CurlShadowPainter({required this.progress, required this.turnNext});

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final foldW = 24.0;
    final rect = turnNext
        ? Rect.fromLTWH(size.width - size.width * p, 0, foldW, size.height)
        : Rect.fromLTWH(size.width * p - foldW, 0, foldW, size.height);
    final grad = LinearGradient(
      colors: [
        Colors.black.withValues(alpha: 0.0),
        Colors.black.withValues(alpha: 0.30 * p),
      ],
      begin: turnNext ? Alignment.centerLeft : Alignment.centerRight,
      end: turnNext ? Alignment.centerRight : Alignment.centerLeft,
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = grad);
  }

  @override
  bool shouldRepaint(covariant _CurlShadowPainter old) =>
      old.progress != progress || old.turnNext != turnNext;
}
