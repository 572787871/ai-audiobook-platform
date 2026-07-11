import 'dart:math' as math;
import 'package:flutter/material.dart' show FontWeight;

/// 阅读排版参数。
class ReaderLayout {
  final double fontSize;
  final FontWeight fontWeight;
  final String? fontFamily;
  final double lineHeight;
  final double paragraphSpacing;
  final double horizontalMargin;
  final double verticalMargin;
  final double pageWidth;
  final double pageHeight;

  const ReaderLayout({
    required this.fontSize,
    required this.fontWeight,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.horizontalMargin,
    required this.verticalMargin,
    required this.pageWidth,
    required this.pageHeight,
    this.fontFamily,
  });

  double get contentWidth => math.max(1.0, pageWidth - horizontalMargin * 2);
  double get contentHeight => math.max(1.0, pageHeight - verticalMargin * 2);
  double get lineHeightPx => fontSize * lineHeight;
}
