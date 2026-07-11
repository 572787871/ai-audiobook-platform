import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show FontWeight;
import 'package:ai_audiobook_platform/features/reader/engine/reader_document.dart';
import 'package:ai_audiobook_platform/features/reader/engine/reader_engine.dart';
import 'package:ai_audiobook_platform/features/reader/engine/reader_layout.dart';
import 'package:ai_audiobook_platform/features/reader/engine/reader_controller.dart';
import 'package:ai_audiobook_platform/features/reader/engine/reader_position.dart';

ReaderLayout _layout({double w = 360, double h = 640}) => ReaderLayout(
      fontSize: 18,
      fontWeight: FontWeight.normal,
      lineHeight: 1.6,
      paragraphSpacing: 1,
      horizontalMargin: 16,
      verticalMargin: 16,
      pageWidth: w,
      pageHeight: h,
    );

void main() {
  test('分页生成独立页且字符范围连续不重叠', () {
    final doc = ReaderDocument.fromContent('第一章 开头。\n这是第一段内容，用于测试分页算法是否稳定。\n' * 40);
    final engine = ReaderEngine(doc, _layout());
    final pages = engine.paginate();
    expect(pages.length, greaterThan(1));
    // 每页独立且范围连续
    var expectStart = 0;
    for (final p in pages) {
      expect(p.startOffset, expectStart);
      expect(p.endOffset, greaterThan(p.startOffset));
      expect(p.text, isNotEmpty);
      expect(p.text, equals(doc.content.substring(p.startOffset, p.endOffset)));
      expectStart = p.endOffset;
    }
    expect(expectStart, doc.content.length);
  });

  test('根据字符偏移定位（不依赖页码）', () {
    final doc = ReaderDocument.fromContent('内容甲\n内容乙\n内容丙\n' * 30);
    final engine = ReaderEngine(doc, _layout());
    final pages = engine.paginate();
    final mid = doc.content.length ~/ 2;
    final idx = engine.pageIndexForOffset(mid, pages);
    expect(pages[idx].startOffset, lessThanOrEqualTo(mid));
    expect(pages[idx].endOffset, greaterThan(mid));
  });

  test('横竖屏变化重分页后页数变化但内容完整', () {
    final doc = ReaderDocument.fromContent('横竖屏测试段落内容。' * 100);
    final portrait = ReaderEngine(doc, _layout(w: 360, h: 640)).paginate();
    final landscape = ReaderEngine(doc, _layout(w: 640, h: 360)).paginate();
    // 横屏更宽更矮，页数通常不同，但总字符一致
    final totalP = portrait.fold(0, (a, p) => a + p.length);
    final totalL = landscape.fold(0, (a, p) => a + p.length);
    expect(totalP, doc.content.length);
    expect(totalL, doc.content.length);
  });

  test('ReaderPosition 由偏移推导进度', () {
    final pos = ReaderPosition.fromOffset(characterOffset: 50, totalCharacters: 200);
    expect(pos.readingProgress, 0.25);
    expect(pos.characterOffset, 50);
  });

  test('控制器跳转到偏移并暴露当前句/段', () {
    final doc = ReaderDocument.fromContent('第一句。第二句。第三句。\n\n另一个段落内容。');
    final engine = ReaderEngine(doc, _layout());
    final ctrl = ReaderController(engine: engine);
    ctrl.goToOffset(0);
    expect(ctrl.currentSentence, contains('第一句'));
    expect(ctrl.currentParagraph, contains('第一句'));
    expect(ctrl.currentCharacterOffset, 0);
  });

  test('首行缩进生效', () {
    final doc = ReaderDocument.fromContent('段落一内容。\n段落二内容。');
    expect(doc.paragraphs.first.startsWith('  '), isTrue);
  });
}
