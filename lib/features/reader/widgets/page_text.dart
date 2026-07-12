library;

import 'package:flutter/cupertino.dart';

/// 单页正文渲染（共享）。在首行前插入首行缩进（按字符数 × 字号计算宽度），
/// 不改变 [ReaderPageModel.text] 本身，因此不影响分页内核与相关断言。
Widget buildPageText({
  required String text,
  required TextStyle style,
  required double firstLineIndentChars,
  TextAlign textAlign = TextAlign.left,
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  ),
}) {
  final indent = (firstLineIndentChars * (style.fontSize ?? 18.0)).clamp(
    0.0,
    200.0,
  );
  return Padding(
    padding: padding,
    child: Text.rich(
      TextSpan(
        children: [
          if (indent > 0) WidgetSpan(child: SizedBox(width: indent)),
          TextSpan(text: text, style: style),
        ],
      ),
      textAlign: textAlign,
    ),
  );
}
