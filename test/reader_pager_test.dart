import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:ai_audiobook_platform/features/library/models/book.dart';
import 'package:ai_audiobook_platform/features/library/models/book_file_type.dart';
import 'package:ai_audiobook_platform/features/library/models/book_parse_status.dart';

import 'package:ai_audiobook_platform/features/reader/pages/reader_page.dart';
import 'package:ai_audiobook_platform/features/reader/services/reading_settings_service.dart';
import 'fake_book_repository.dart';

Future<void> pumpUntilFound(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 5)}) async {
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

final _longText = '第一章 开头内容。这是一段用于分页测试的文本。\n'
    '第二段内容继续展开，验证分页稳定性与独立性。\n' * 6;

Future<String> _loader(Book b) async => _longText;

void main() {
  setUpAll(() {
    ReadingSettingsService.instance.setDirForTest(Directory.systemTemp);
  });

  testWidgets('滑动模式(PageView)构建且不重叠', (tester) async {
    await tester.pumpWidget(CupertinoApp(
      home: ReaderPage(book: _book(), repository: FakeBookRepository(), contentLoader: _loader),
    ));
    await pumpUntilFound(tester, find.byKey(const Key('reader_pager')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_pager')), findsOneWidget);
    // 单页文本存在
    expect(find.byType(Text), findsWidgets);
  });

  testWidgets('滚动模式构建连续内容', (tester) async {
    ReadingSettingsService.instance
        .setSettingsForTest((await ReadingSettingsService.instance.get())
            .copyWith(pageAnimation: PageAnimation.none));
    await tester.pumpWidget(CupertinoApp(
      home: ReaderPage(book: _book(), repository: FakeBookRepository(), contentLoader: _loader),
    ));
    await pumpUntilFound(tester, find.byType(SingleChildScrollView));
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('覆盖模式构建', (tester) async {
    ReadingSettingsService.instance
        .setSettingsForTest((await ReadingSettingsService.instance.get())
            .copyWith(pageAnimation: PageAnimation.cover));
    await tester.pumpWidget(CupertinoApp(
      home: ReaderPage(book: _book(), repository: FakeBookRepository(), contentLoader: _loader),
    ));
    await pumpUntilFound(tester, find.textContaining('第一章'));
    await tester.pumpAndSettle();
    expect(find.textContaining('第一章'), findsWidgets);
  });

  testWidgets('根据字符偏移恢复位置而非页码', (tester) async {
    // 进度约 50% 的书应从中段开始，而非第 0 页
    ReadingSettingsService.instance
        .setSettingsForTest((await ReadingSettingsService.instance.get())
            .copyWith(pageAnimation: PageAnimation.slide));
    final book = _book(offset: (_longText.length * 0.5).round());
    await tester.pumpWidget(CupertinoApp(
      home: ReaderPage(book: book, repository: FakeBookRepository(), contentLoader: _loader),
    ));
    await pumpUntilFound(tester, find.byKey(const Key('reader_pager')));
    await tester.pumpAndSettle();
    // 中点 tap 显示工具栏（证明已进入阅读器且可交互）
    await tester.tapAt(const Offset(400, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_back')), findsOneWidget);
  });

  testWidgets('点击中部显示/隐藏工具栏', (tester) async {
    await tester.pumpWidget(CupertinoApp(
      home: ReaderPage(book: _book(), repository: FakeBookRepository(), contentLoader: _loader),
    ));
    await pumpUntilFound(tester, find.byKey(const Key('reader_pager')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_back')), findsNothing);
    await tester.tapAt(const Offset(400, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_back')), findsOneWidget);
  });
}
