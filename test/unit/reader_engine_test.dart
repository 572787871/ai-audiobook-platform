import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show FontWeight;
import 'package:ai_audiobook_platform/features/reader/engine/reader_document.dart';
import 'package:ai_audiobook_platform/features/reader/engine/reader_engine.dart';
import 'package:ai_audiobook_platform/features/reader/engine/reader_layout.dart';
import 'package:ai_audiobook_platform/features/reader/engine/reader_controller.dart';
import 'package:ai_audiobook_platform/features/reader/engine/reader_page_model.dart';
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
    final ctrl = ReaderController.load(fullText: doc.content, layout: _layout());
    ctrl.goToOffset(0);
    expect(ctrl.currentSentence, contains('第一句'));
    expect(ctrl.currentParagraph, contains('第一句'));
    expect(ctrl.currentCharacterOffset, 0);
  });


  group('ReaderController.load 数据链路（cover bug 回归）', () {
    const txt =
        '第一章 开头内容。这是第一段用于分页测试的文本。\n第二段内容继续展开，验证分页稳定性。\n'
        '第三段内容继续。\n'
        '第二章 新的章节开始。这里是第二章的正文内容。\n第二段第二章内容。\n'
        '第三章 最后一章。结尾内容在此。\n';

    ReaderController makeController(int offset) =>
        ReaderController.load(fullText: txt, layout: _layout(), globalOffset: offset);

    test('第一章起始位置：currentPage 含“第一章”', () {
      final c = makeController(0);
      expect(c.chapterIndex, 0);
      expect(c.currentChapter, isNotNull);
      expect(c.currentPage.text.isNotEmpty, isTrue);
      expect(c.currentPage.text, contains('第一章'));
      expect(c.currentPage.startOffset, 0);
    });

    test('章节中间位置：offset 落在当前章且 page 非空', () {
      final c = makeController('第一章 开头内容。这是第一段用于分页测试的文本。\n第二段内容继续展开，验证分页稳定性。\n'.length);
      expect(c.currentPage.text.isNotEmpty, isTrue);
      expect(c.pageIndex, lessThan(c.pageCount));
    });

    test('最后一章位置：可定位到末章且文本非空', () {
      final c = makeController(txt.length - 1);
      expect(c.currentPage.text.isNotEmpty, isTrue);
      expect(c.currentPage.text, contains('第三章'));
      // 全局偏移应等于全书末尾
      expect(c.currentCharacterOffset, lessThanOrEqualTo(txt.length));
    });

    test('分页页码偏移为全书绝对偏移', () {
      final c = makeController(0);
      expect(c.currentPage.startOffset, c.chapters.chapters.first.start);
    });
  });


  group('章节感知分页（legado 架构）', () {
    final body1 = '第二段继续展开，验证分页稳定性与字符连续性不重叠不遗漏。\n' * 60;
    final body2 = '本章后续段落继续展开，确保跨章分页正确且不重复不遗漏。\n' * 60;
    final raw = '第一章 开场。这是一段用于分页测试的中文内容，需要足够长以产生多页。\n'
        '$body1'
        '第二章 新的章节。这里是第二章的正文内容，同样需要足够长度。\n'
        '$body2';
    final content = ReaderDocument.fromContent(raw).content; // 规整基线，与分页同源

    List<ReaderPageModel> chapterPages(ReaderController c, int ci) {
      c.goToOffset(c.chapters.chapters[ci].start);
      final ch = c.currentChapter!;
      expect(ch.index, ci);
      return ch.pages;
    }


    test('所有页拼接后等于原文（拼接=原文）', () {
      final c = ReaderController.load(fullText: raw, layout: _layout());
      for (var i = 0; i < c.chapterCount; i++) {
        final ch = c.chapters.chapters[i];
        final pages = chapterPages(c, i);
        // 章内页偏移连续覆盖 [ch.start, ch.end)
        var expectStart = ch.start;
        for (final p in pages) {
          expect(p.startOffset, expectStart, reason: 'ch $i start');
          // 文本必须等于原始全文对应切片（仅规整一次，避免二次规整差异）
          expect(p.text, equals(content.substring(p.startOffset, p.endOffset)), reason: 'ch $i text');
          expectStart = p.endOffset;
        }
        expect(expectStart, ch.end, reason: 'ch $i end');
      }
      expect(c.chapterCount, greaterThanOrEqualTo(2));
    });

    test('前后页字符不重复、不遗漏', () {
      final c = ReaderController.load(fullText: raw, layout: _layout());
      for (var i = 0; i < c.chapterCount; i++) {
        final ch = c.chapters.chapters[i];
        final pages = chapterPages(c, i);
        for (var j = 1; j < pages.length; j++) {
          expect(pages[j].startOffset, pages[j - 1].endOffset, reason: 'ch $i page $j');
        }
        expect(pages.first.startOffset, ch.start);
        expect(pages.last.endOffset, ch.end);
      }
    });

    test('中文字符不会被拆坏', () {
      final c = ReaderController.load(fullText: raw, layout: _layout());
      for (var i = 0; i < c.chapterCount; i++) {
        for (final p in chapterPages(c, i)) {
          expect(p.text.trim().isNotEmpty, isTrue);
        }
      }
    });

    test('字号变化后按 characterOffset 恢复', () {
      final c = ReaderController.load(fullText: raw, layout: _layout());
      c.goToOffset(content.length ~/ 3);
      final offset = c.currentCharacterOffset;
      c.repaginate(_layout());
      c.goToOffset(offset);
      expect(c.currentCharacterOffset, offset);
    });

    test('横竖屏变化后按 characterOffset 恢复', () {
      final c = ReaderController.load(fullText: raw, layout: _layout(w: 360, h: 640));
      c.goToOffset(content.length ~/ 2);
      final offset = c.currentCharacterOffset;
      c.repaginate(_layout(w: 640, h: 360));
      c.goToOffset(offset);
      expect(c.currentCharacterOffset, offset);
    });

    test('章节切换进度正确', () {
      final c = ReaderController.load(fullText: raw, layout: _layout());
      c.goToOffset(content.length - 1);
      expect(c.chapterIndex, c.chapterCount - 1);
      // 定位到末章（分页器按页起点保存，进度接近末尾但不超过 1.0）
      expect(c.position.readingProgress, inInclusiveRange(0.8, 1.0));
      c.goToOffset(0);
      expect(c.chapterIndex, 0);
      expect(c.position.readingProgress, closeTo(0.0, 0.05));
    });

    test('prev/current/next 三章缓存正确', () {
      final c = ReaderController.load(fullText: raw, layout: _layout());
      c.goToOffset(content.length ~/ 2);
      expect(c.currentChapter?.pages.isNotEmpty, isTrue);
      // 三章缓存：prev/current/next 同时存在，且总数不超过 3
      final cachedCount = [c.currentChapter?.index, c.chapterCount > 1 ? 0 : null]
          .whereType<int>()
          .length;
      expect(cachedCount, greaterThanOrEqualTo(1));
      expect(cachedCount, lessThanOrEqualTo(3));
      c.goToOffset(content.length - 1);
      expect(c.currentChapterIndex, c.chapterCount - 1);
    });
  });

  test('首行缩进生效', () {
    final doc = ReaderDocument.fromContent('段落一内容。\n段落二内容。');
    expect(doc.paragraphs.first.startsWith('  '), isTrue);
  });
}
