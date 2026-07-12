library;

import 'package:flutter/cupertino.dart';
import '../engine/reader_controller.dart';
import 'page_text.dart';

/// 无动画整页翻：点击右侧进入下一页，点击左侧进入上一页，
/// 跨章节由 [ReaderController.moveNext] / [ReaderController.movePrevious] 统一处理。
class NoAnimReader extends StatelessWidget {
  final ReaderController controller;
  final TextStyle textStyle;
  final Color textColor;
  final double firstLineIndentChars;
  final void Function(int globalOffset) onPageSettled;

  const NoAnimReader({
    super.key,
    required this.controller,
    required this.textStyle,
    required this.textColor,
    required this.firstLineIndentChars,
    required this.onPageSettled,
  });

  @override
  Widget build(BuildContext context) {
    final page = controller.currentPage;
    return GestureDetector(
      onTapUp: (d) {
        final w = MediaQuery.of(context).size.width;
        if (d.localPosition.dx < 24) return; // 最左交给系统返回
        final Future<bool> Function() action =
            d.localPosition.dx >= w / 2 ? controller.moveNext : controller.movePrevious;
        final moved = d.localPosition.dx >= w / 2
            ? controller.hasNext
            : controller.hasPrev;
        if (!moved) return;
        action().then((_) {
          if (context.mounted) onPageSettled(controller.currentCharacterOffset);
        });
      },
      child: Container(
        color: CupertinoColors.transparent,
        alignment: Alignment.centerLeft,
        child: buildPageText(
          text: page.text,
          style: textStyle.copyWith(color: textColor),
          firstLineIndentChars: firstLineIndentChars,
        ),
      ),
    );
  }
}
