import 'dart:math' as math;
import 'package:flutter/material.dart' show TextPainter, TextSpan, TextStyle, TextAlign, TextDirection;
import 'reader_document.dart';
import 'reader_layout.dart';
import 'reader_page_model.dart';

/// 文本分页器：基于字符级测量，逐页生成真正独立的 [ReaderPageModel]。
///
/// 算法（逐字符测量，稳定无重叠）：
///  - 用 [TextPainter] 在给定 [ReaderLayout] 下测量"当前行"宽度；
///  - 遇到显式 \n 或当前行宽度超过 contentWidth 则换行；
///  - 累计行数达到每页最大行数（contentHeight / lineHeightPx）时 flush 为一页；
///  - 每页记录 [startOffset, endOffset) 字符范围与纯文本，独立渲染。
///
/// 支持中文 / UTF-8 / GBK / GB18030 / BIG5 / UTF16（均按 String 字符处理）、首行缩进、
/// 段落间距、字号变化、横竖屏变化（传入新 [ReaderLayout] 重新 [paginate]）。
class TextPaginator {
  final ReaderDocument document;
  final ReaderLayout layout;

  const TextPaginator(this.document, this.layout);

  List<ReaderPageModel> paginate() {
    final text = document.content;
    if (text.isEmpty) {
      return const [ReaderPageModel(startOffset: 0, endOffset: 0, text: '')];
    }

    final style = TextStyle(
      fontSize: layout.fontSize,
      fontWeight: layout.fontWeight,
      fontFamily: layout.fontFamily,
      height: layout.lineHeight,
    );
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );
    final contentWidth = layout.contentWidth;
    final maxLinesPerPage =
        math.max(1, (layout.contentHeight / layout.lineHeightPx).floor());

    final pages = <ReaderPageModel>[];
    var pageStart = 0; // 当前页起始字符偏移
    var lineCount = 0; // 当前页已累计行数
    var lineStart = 0; // 当前行在 text 中的起始偏移
    var lineText = ''; // 当前行文本（不含换行符）

    void flushPage(int endExclusive) {
      pages.add(ReaderPageModel(
        startOffset: pageStart,
        endOffset: endExclusive,
        text: text.substring(pageStart, endExclusive),
      ));
      pageStart = endExclusive;
      lineCount = 0;
    }

    void newLine(int nextLineStart) {
      // 将当前行提交到当前页
      if (lineText.isNotEmpty) {
        lineCount++;
        lineStart = nextLineStart;
        lineText = '';
        if (lineCount >= maxLinesPerPage) {
          flushPage(lineStart);
        }
      } else {
        lineStart = nextLineStart;
      }
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '\n') {
        newLine(i + 1);
        continue;
      }
      final test = lineText + ch;
      painter.text = TextSpan(text: test, style: style);
      painter.layout(maxWidth: contentWidth);
      if (painter.width > contentWidth && lineText.isNotEmpty) {
        // 当前行满：提交当前行（含已有内容，不含本字符），本字符作为新行起点
        final end = lineStart + lineText.length;
        lineCount++;
        lineText = ch;
        lineStart = i;
        if (lineCount >= maxLinesPerPage) {
          flushPage(end);
        }
      } else {
        lineText = test;
      }
    }
    // 收尾：最后一行 + 最后可能未满的页
    if (lineText.isNotEmpty) {
      lineCount++;
      if (lineCount > maxLinesPerPage) {
        flushPage(text.length);
      }
    }
    if (pageStart < text.length) {
      flushPage(text.length);
    }
    return pages;
  }
}
