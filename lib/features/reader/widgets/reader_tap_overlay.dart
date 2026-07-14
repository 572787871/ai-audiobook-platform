library;

import 'package:flutter/cupertino.dart';

/// 阅读区手势分区（沉浸态下的透明命中层）：
///  - 最左 24pt：永远交给 iOS interactive pop（不处理、不拦截）；
///  - 左 25%：上一页；
///  - 中 50%：显示/隐藏工具栏；
///  - 右 25%：下一页（不含被系统返回占用的 24pt）。
class ReaderTapOverlay extends StatelessWidget {
  final void Function() onTapPrevious;
  final void Function() onToggleToolbar;
  final void Function() onTapNext;

  const ReaderTapOverlay({
    super.key,
    required this.onTapPrevious,
    required this.onToggleToolbar,
    required this.onTapNext,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final edge = 24.0; // iOS 左边缘返回保留区
        final leftZoneW = (w - edge) * 0.25;
        final centerZoneW = (w - edge) * 0.5;
        final rightZoneW = (w - edge) * 0.25;
        return Stack(
          children: [
            // 左 25%：上一页（从 24pt 之后开始）
            // 使用 translucent 让滑动手势穿透到下方阅读器组件
            Positioned(
              left: edge,
              top: 0,
              bottom: 0,
              width: leftZoneW,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onTapPrevious,
                child: const SizedBox.expand(),
              ),
            ),
            // 中 50%：显隐工具栏
            Positioned(
              left: edge + leftZoneW,
              top: 0,
              bottom: 0,
              width: centerZoneW,
              child: GestureDetector(
                key: const Key('reader_tap_center'),
                behavior: HitTestBehavior.opaque,
                onTap: onToggleToolbar,
                child: const SizedBox.expand(),
              ),
            ),
            // 右 25%：下一页
            // 使用 translucent 让滑动手势穿透到下方阅读器组件
            Positioned(
              left: w - rightZoneW,
              top: 0,
              bottom: 0,
              width: rightZoneW,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onTapNext,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }
}
