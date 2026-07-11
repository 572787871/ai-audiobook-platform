library;

import 'package:flutter/cupertino.dart';
import '../engine/reader_controller.dart';
import '../engine/reader_page_model.dart';

/// 连续滚动阅读：当前章与相邻章的页拼接为可滚动列，每页独立 Text，不重叠。
class ScrollReader extends StatelessWidget {
  final ReaderController controller;
  final TextStyle textStyle;
  final Color textColor;

  const ScrollReader({
    super.key,
    required this.controller,
    required this.textStyle,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final pages = controller.currentChapterPagesWithNeighbors;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: pages.map((p) => _PageText(p: p, style: textStyle, color: textColor)).toList(),
      ),
    );
  }
}

class _PageText extends StatelessWidget {
  final ReaderPageModel p;
  final TextStyle style;
  final Color color;
  const _PageText({required this.p, required this.style, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        p.text,
        style: style.copyWith(color: color),
        textAlign: TextAlign.left,
      ),
    );
  }
}
