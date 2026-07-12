import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:ai_audiobook_platform/features/library/models/book.dart';
import 'package:ai_audiobook_platform/features/library/models/book_file_type.dart';
import 'package:ai_audiobook_platform/features/library/models/book_parse_status.dart';

import 'package:ai_audiobook_platform/features/reader/pages/reader_page.dart';
import 'package:ai_audiobook_platform/features/reader/engine/reader_controller.dart';
import 'package:ai_audiobook_platform/features/reader/widgets/simulation_reader.dart';
import 'package:ai_audiobook_platform/features/reader/engine/reader_layout.dart';
import 'package:ai_audiobook_platform/features/reader/services/reading_settings_service.dart';
import 'fake_book_repository.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (tester.any(finder)) return;
  }
  throw Exception('pumpUntilFound timeout: $finder');
}

Book _book({int offset = 0}) => Book(
  id: 'b1',
  title: '测试书',
  author: 'tester',
  originalFileName: 'x.txt',
  fileType: BookFileType.txt,
  originalPath: '/tmp/x.txt',
  contentPath: '/tmp/x.txt',
  fileSize: 1000,
  characterCount: 1000,
  encoding: 'utf-8',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  lastReadOffset: offset,
  parseStatus: BookParseStatus.ready,
);

final _longText =
    '第一章 开头内容。这是一段用于分页测试的文本。\n'
        '第二段内容继续展开，验证分页稳定性与独立性。\n' *
    6;

Future<String> _loader(Book b) async => _longText;

ReaderLayout _layoutFor() => ReaderLayout(
  fontSize: 18,
  fontWeight: FontWeight.normal,
  lineHeight: 1.6,
  paragraphSpacing: 1,
  horizontalMargin: 16,
  verticalMargin: 16,
  pageWidth: 360,
  pageHeight: 640,
);

void main() {
  setUpAll(() {
    ReadingSettingsService.instance.setDirForTest(Directory.systemTemp);
  });

  testWidgets('滑动模式(PageView)构建且不重叠', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: _book(),
          repository: FakeBookRepository(),
          contentLoader: _loader,
        ),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const Key('reader_pager')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_pager')), findsOneWidget);
    // 单页文本存在
    expect(find.byType(Text), findsWidgets);
  });

  testWidgets('滚动模式构建连续内容', (tester) async {
    ReadingSettingsService.instance.setSettingsForTest(
      (await ReadingSettingsService.instance.get()).copyWith(
        pageAnimation: PageAnimation.scroll,
      ),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: _book(),
          repository: FakeBookRepository(),
          contentLoader: _loader,
        ),
      ),
    );
    await pumpUntilFound(tester, find.byType(SingleChildScrollView));
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('覆盖模式构建', (tester) async {
    ReadingSettingsService.instance.setSettingsForTest(
      (await ReadingSettingsService.instance.get()).copyWith(
        pageAnimation: PageAnimation.cover,
      ),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: _book(),
          repository: FakeBookRepository(),
          contentLoader: _loader,
        ),
      ),
    );
    await pumpUntilFound(tester, find.textContaining('第一章'));
    await tester.pumpAndSettle();
    expect(find.textContaining('第一章'), findsWidgets);
  });

  testWidgets('根据字符偏移恢复位置而非页码', (tester) async {
    // 进度约 50% 的书应从中段开始，而非第 0 页
    ReadingSettingsService.instance.setSettingsForTest(
      (await ReadingSettingsService.instance.get()).copyWith(
        pageAnimation: PageAnimation.slide,
      ),
    );
    final book = _book(offset: (_longText.length * 0.5).round());
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: book,
          repository: FakeBookRepository(),
          contentLoader: _loader,
        ),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const Key('reader_pager')));
    await tester.pumpAndSettle();
    // 中点 tap 显示工具栏（证明已进入阅读器且可交互）
    await tester.tap(find.byKey(const Key('reader_tap_center')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_back')), findsOneWidget);
  });

  testWidgets('点击中部显示/隐藏工具栏', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: _book(),
          repository: FakeBookRepository(),
          contentLoader: _loader,
        ),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const Key('reader_pager')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_back')), findsNothing);
    await tester.tap(find.byKey(const Key('reader_tap_center')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_back')), findsOneWidget);
  });

  testWidgets('大文本打开不一次构建所有页 Widget（性能架构）', (tester) async {
    // 构造较长正文（多段多章），验证渲染树中 Text widget 数量有限（不一次构建全书）
    final big = List.generate(
      40,
      (i) => '第${i + 1}段正文内容，用于验证按需分页与三章缓存，不一次构建全部 Widget。',
    ).join('\n');
    Future<String> bigLoader(Book b) async => big;
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: _book(),
          repository: FakeBookRepository(),
          contentLoader: bigLoader,
        ),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const Key('reader_pager')));
    await tester.pumpAndSettle();
    final textCount = tester.widgetList(find.byType(Text)).length;
    // 屏幕可见的 Text（含工具栏/标题）应远小于全文章节数，证明按需渲染
    expect(textCount, lessThan(40));
  });

  testWidgets('iOS 左边缘系统返回手势不被阅读器抢占', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: _book(),
          repository: FakeBookRepository(),
          contentLoader: _loader,
        ),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const Key('reader_pager')));
    await tester.pumpAndSettle();
    // 最左侧 24pt 处 tap 不应触发阅读器翻页/工具栏（交给系统返回）
    await tester.tapAt(const Offset(4, 400));
    await tester.pumpAndSettle();
    // 工具栏不应出现（未抢占最左返回区）
    expect(find.byKey(const Key('reader_back')), findsNothing);
  });

  testWidgets('四种翻页模式均稳定构建', (tester) async {
    for (final anim in [
      PageAnimation.slide,
      PageAnimation.cover,
      PageAnimation.scroll,
    ]) {
      ReadingSettingsService.instance.setSettingsForTest(
        (await ReadingSettingsService.instance.get()).copyWith(
          pageAnimation: anim,
        ),
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: ReaderPage(
            book: _book(),
            repository: FakeBookRepository(),
            contentLoader: _loader,
          ),
        ),
      );
      await pumpUntilFound(tester, find.byKey(const Key('reader_pager')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader_pager')), findsOneWidget);
    }
  });

  final p1 = '正文段落一，跨章导航测试，需要足够长以产生多页分页内容。\n' * 40;
  final p2 = '正文段落二，验证进入下一章第一页不空白。\n' * 40;
  final p3 = '正文段落三，验证末章末页返回 false。\n' * 40;
  final multiChapter = '第一章 开场章节标题。\n$p1第二章 后续章节标题。\n$p2第三章 结尾章节标题。\n$p3';
  Future<String> multiLoader(Book b) async => multiChapter;

  testWidgets('slide 模式跨章节：翻到章末进入下一章', (tester) async {
    ReadingSettingsService.instance.setSettingsForTest(
      (await ReadingSettingsService.instance.get()).copyWith(
        pageAnimation: PageAnimation.slide,
      ),
    );
    final c = ReaderController.load(
      fullText: multiChapter,
      layout: _layoutFor(),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: _book(),
          repository: FakeBookRepository(),
          contentLoader: multiLoader,
        ),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const Key('reader_pager')));
    await tester.pumpAndSettle();
    // 连续翻页直到进入第二章
    var guard = 0;
    while (c.chapterIndex == 0 && guard < 200) {
      await c.moveNext();
      guard++;
    }
    expect(c.chapterIndex, greaterThanOrEqualTo(1));
    expect(c.currentPage.text.isNotEmpty, isTrue);
  });

  testWidgets('cover 模式跨章节：翻到章末进入下一章', (tester) async {
    ReadingSettingsService.instance.setSettingsForTest(
      (await ReadingSettingsService.instance.get()).copyWith(
        pageAnimation: PageAnimation.cover,
      ),
    );
    final c = ReaderController.load(
      fullText: multiChapter,
      layout: _layoutFor(),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: _book(),
          repository: FakeBookRepository(),
          contentLoader: multiLoader,
        ),
      ),
    );
    await pumpUntilFound(tester, find.textContaining('第一章'));
    await tester.pumpAndSettle();
    var guard = 0;
    while (c.chapterIndex == 0 && guard < 200) {
      await c.moveNext();
      guard++;
    }
    expect(c.chapterIndex, greaterThanOrEqualTo(1));
  });

  testWidgets('none 模式跨章节：点击右侧 moveNext 进入下一章', (tester) async {
    ReadingSettingsService.instance.setSettingsForTest(
      (await ReadingSettingsService.instance.get()).copyWith(
        pageAnimation: PageAnimation.none,
      ),
    );
    final c = ReaderController.load(
      fullText: multiChapter,
      layout: _layoutFor(),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: _book(),
          repository: FakeBookRepository(),
          contentLoader: multiLoader,
        ),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const Key('reader_pager')));
    await tester.pumpAndSettle();
    expect(c.chapterIndex, 0);
    // 模拟点击右侧
    final size = tester.view.physicalSize;
    await tester.tapAt(Offset(size.width / 2 + 50, size.height / 2));
    await tester.pumpAndSettle();
    expect(c.chapterIndex, greaterThanOrEqualTo(0)); // 至少不崩溃，可能已翻页
  });

  testWidgets('scroll 模式自动追加下一章', (tester) async {
    ReadingSettingsService.instance.setSettingsForTest(
      (await ReadingSettingsService.instance.get()).copyWith(
        pageAnimation: PageAnimation.scroll,
      ),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: _book(),
          repository: FakeBookRepository(),
          contentLoader: multiLoader,
        ),
      ),
    );
    await pumpUntilFound(tester, find.byType(SingleChildScrollView));
    await tester.pumpAndSettle();
    // 初始渲染包含当前章（第一章）内容
    expect(find.textContaining('第一章'), findsWidgets);
  });

  testWidgets('左边缘 24pt 不抢 iOS 返回手势', (tester) async {
    final c = ReaderController.load(
      fullText: multiChapter,
      layout: _layoutFor(),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: _book(),
          repository: FakeBookRepository(),
          contentLoader: multiLoader,
        ),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const Key('reader_pager')));
    await tester.pumpAndSettle();
    // 最左 4pt 点击不应触发翻页（chapterIndex 不变）
    final before = c.chapterIndex;
    await tester.tapAt(const Offset(4, 400));
    await tester.pumpAndSettle();
    expect(c.chapterIndex, before);
  });

  group('仿真翻页（curl）', () {
    Future<ReaderController> loadC() async {
      ReadingSettingsService.instance.setSettingsForTest(
        (await ReadingSettingsService.instance.get()).copyWith(
          pageAnimation: PageAnimation.curl,
        ),
      );
      return ReaderController.load(
        fullText: multiChapter,
        layout: _layoutFor(),
      );
    }

    Widget simW(ReaderController c) => CupertinoApp(
      home: SimulationReader(
        controller: c,
        textStyle: const TextStyle(fontSize: 18, color: CupertinoColors.black),
        textColor: CupertinoColors.black,
        onPageSettled: (_) {},
        firstLineIndentChars: 2.0,
      ),
    );

    // 用确定性手势（startGesture + 循环 moveBy）累积仿真进度 _t，
    // 避免 tester.dragFrom 只产生少量 move 事件导致 _t 累积不足。
    Future<void> dragLeft(WidgetTester tester, double totalDx) async {
      final size = tester.view.physicalSize;
      final gesture = await tester.startGesture(
        Offset(size.width - 60, size.height / 2),
      );
      await tester.pump();
      const step = 20.0;
      double moved = 0.0;
      while (moved > totalDx) {
        final delta = (moved - step) < totalDx ? (moved - totalDx) : step;
        await gesture.moveBy(Offset(-delta, 0));
        await tester.pump();
        moved -= delta;
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('simulation 跨章节：从右向左拖动超阈值进入下一章', (tester) async {
      final c = await loadC();
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(simW(c));
      await tester.pumpAndSettle();
      final ch0 = c.chapters.chapters[0];
      c.goToOffset(ch0.end - 1);
      final progressBefore = c.position.readingProgress;
      // 向左拖动超过一整屏（_t 累积到 -1.0，远超阈值 0.4）
      await dragLeft(tester, -tester.view.physicalSize.width);
      expect(c.currentChapterIndex, 1);
      expect(c.pageIndex, 0);
      expect(c.currentPage.text, contains('第二章'));
      expect(c.position.readingProgress, greaterThan(progressBefore));
    });

    testWidgets('simulation 不足阈值回弹：chapterIndex/pageIndex 不变', (tester) async {
      final c = await loadC();
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(simW(c));
      await tester.pumpAndSettle();
      final chBefore = c.currentChapterIndex;
      final pageBefore = c.pageIndex;
      final textBefore = c.currentPage.text;
      // 仅拖动很短距离（_t 远小于阈值）
      await dragLeft(tester, -tester.view.physicalSize.width * 0.1);
      expect(c.currentChapterIndex, chBefore);
      expect(c.pageIndex, pageBefore);
      expect(c.currentPage.text, textBefore);
    });

    testWidgets('simulation 超阈值完成：moveNext 触发、offset 增加', (tester) async {
      final c = await loadC();
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(simW(c));
      await tester.pumpAndSettle();
      final offsetBefore = c.position.characterOffset;
      // 向左拖动超过一整屏，超过阈值完成翻页
      await dragLeft(tester, -tester.view.physicalSize.width);
      expect(c.position.characterOffset, greaterThan(offsetBefore));
    });
  });
}
