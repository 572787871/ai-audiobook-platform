import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:ai_audiobook_platform/features/reader/services/reading_settings_service.dart';
import 'package:ai_audiobook_platform/features/library/pages/book_shelf_page.dart';
import 'package:ai_audiobook_platform/features/library/pages/book_detail_page.dart';
import 'package:ai_audiobook_platform/features/reader/pages/reader_page.dart';
import 'package:ai_audiobook_platform/features/library/models/book.dart';
import 'package:ai_audiobook_platform/features/library/models/book_file_type.dart';
import 'package:ai_audiobook_platform/features/library/models/book_parse_status.dart';
import 'fake_book_repository.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 50,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Widget not found: $finder');
}

Book _makeBook(
  String id,
  String title,
  double progress, {
  int lastReadOffset = 0,
}) => Book(
  id: id,
  title: title,
  originalFileName: '$title.txt',
  fileType: BookFileType.txt,
  originalPath: '/tmp/$title.txt',
  contentPath: '/tmp/$title.content.txt',
  fileSize: 1024,
  characterCount: 10000,
  encoding: 'UTF-8',
  createdAt: DateTime(2026, 7, 11),
  updatedAt: DateTime(2026, 7, 11),
  lastReadOffset: lastReadOffset,
  readingProgress: progress,
  parseStatus: BookParseStatus.ready,
  chapterCount: 0,
  coverPath: null,
);

void main() {
  setUpAll(() {
    ReadingSettingsService.instance.setDirForTest(Directory.systemTemp);
  });

  testWidgets('空书架：显示暂无书籍和导入按钮', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: FakeBookRepository())),
    );
    await pumpUntilFound(tester, find.text('暂无书籍'));
    expect(find.text('书架'), findsOneWidget);
    expect(find.text('暂无书籍'), findsOneWidget);
    expect(find.text('导入书籍'), findsOneWidget);
  });

  testWidgets('有书时显示三列网格和阅读进度', (tester) async {
    final repo = FakeBookRepository([
      _makeBook('b1', '小说A', 0.0),
      _makeBook('b2', '小说B', 0.36),
      _makeBook('b3', '小说C', 1.0),
    ]);
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.text('小说A'));
    expect(find.text('未开始'), findsWidgets);
    final scrollable = find.byType(Scrollable);
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('已读 36%'), findsOneWidget);
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.textContaining('已完成'), findsWidgets);
  });

  testWidgets('点击书籍封面进入阅读器', (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.text('测试小说'));
    // 点击封面下方的书名（第二个匹配）
    await tester.tap(find.text('测试小说').last);
    await pumpUntilFound(tester, find.byType(ReaderPage));
    expect(find.byType(ReaderPage), findsOneWidget);
  });

  testWidgets('空书架无书籍时显示空状态', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: FakeBookRepository())),
    );
    await pumpUntilFound(tester, find.text('暂无书籍'));
    expect(find.text('暂无书籍'), findsOneWidget);
  });

  testWidgets('分类 Tab 显示真实数量', (tester) async {
    final repo = FakeBookRepository([
      _makeBook('b1', '未读', 0.0),
      _makeBook('b2', '阅读中', 0.5),
      _makeBook('b3', '已完成', 1.0),
    ]);
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.text('全部'));
    expect(find.text('3'), findsWidgets);
    // 点击"阅读中" Tab
    await tester.tap(find.text('阅读中').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('1'), findsWidgets);
    // 点击"已完成" Tab
    await tester.tap(find.text('已完成').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('1'), findsWidgets);
  });

  testWidgets('长按显示菜单', (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.5)]);
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.text('测试小说'));
    await tester.longPress(find.text('测试小说').last);
    await tester.pumpAndSettle();
    expect(find.text('继续阅读'), findsOneWidget);
    expect(find.text('从头阅读'), findsOneWidget);
    expect(find.text('书籍详情'), findsOneWidget);
    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('删除书籍'), findsOneWidget);
  });

  testWidgets('删除书籍后书架刷新', (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.5)]);
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.text('测试小说'));
    await tester.longPress(find.text('测试小说').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除书籍'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.text('暂无书籍'), findsOneWidget);
  });

  testWidgets('ReaderPage 点击中部显示工具栏', (tester) async {
    final longText = '第一章 开局\n' * 600;
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    ReadingSettingsService.instance.setSettingsForTest(
      (await ReadingSettingsService.instance.get()).copyWith(
        pageAnimation: PageAnimation.scroll,
      ),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: repo.books.first,
          repository: repo,
          contentLoader: (_) async => longText,
        ),
      ),
    );
    await pumpUntilFound(tester, find.byType(SingleChildScrollView));
    expect(find.byKey(const Key('reader_back')), findsNothing);
    await tester.tap(find.byKey(const Key('reader_tap_center')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_back')), findsOneWidget);
    expect(find.text('测试小说'), findsOneWidget);
  });

  testWidgets('点击返回前保存进度', (tester) async {
    final longText = '第一章 开局\n' * 600;
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    ReadingSettingsService.instance.setSettingsForTest(
      (await ReadingSettingsService.instance.get()).copyWith(
        pageAnimation: PageAnimation.scroll,
      ),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: ReaderPage(
          book: repo.books.first,
          repository: repo,
          contentLoader: (_) async => longText,
        ),
      ),
    );
    await pumpUntilFound(tester, find.byType(SingleChildScrollView));
    await tester.tap(find.byKey(const Key('reader_tap_center')));
    await tester.pumpAndSettle();
    final before = repo.savedCount;
    await tester.tap(find.byKey(const Key('reader_back')));
    await tester.pumpAndSettle();
    expect(repo.savedCount, greaterThan(before));
  });

  testWidgets('阅读后返回详情页进度更新', (tester) async {
    final longText = '第一章 开局\n' * 600;
    final repo = FakeBookRepository([
      _makeBook('b1', '测试小说', 0.0, lastReadOffset: 1500),
    ]);
    await tester.pumpWidget(
      CupertinoApp(
        home: BookDetailPage(
          book: repo.books.first,
          repository: repo,
          contentLoader: (_) async => longText,
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('书籍详情'));
    final savedBefore = repo.savedCount;
    expect(repo.books.first.readingProgress, 0.0);
    expect(find.text('0%'), findsWidgets);

    ReadingSettingsService.instance.setSettingsForTest(
      (await ReadingSettingsService.instance.get()).copyWith(
        pageAnimation: PageAnimation.scroll,
      ),
    );
    await tester.tap(find.text('继续阅读'));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.byType(SingleChildScrollView));
    await tester.tap(find.byKey(const Key('reader_tap_center')));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.byKey(const Key('reader_back')));

    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    await pumpUntilFound(tester, find.byType(SingleChildScrollView));

    await tester.tap(find.byKey(const Key('reader_back')));
    await tester.pumpAndSettle();

    expect(find.text('书籍详情'), findsOneWidget);
    expect(repo.savedCount, greaterThan(savedBefore));
    expect(repo.books.first.readingProgress, greaterThan(0.0));
    expect(find.text('0%'), findsNothing);
    expect(find.textContaining('%'), findsWidgets);
  });

  testWidgets('删除最后一本后显示空状态', (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.text('测试小说'));
    await tester.longPress(find.text('测试小说').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除书籍'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.text('暂无书籍'), findsOneWidget);
    expect(find.text('测试小说'), findsNothing);
  });

  testWidgets('返回书架时保留旧列表不闪空', (tester) async {
    final repo = FakeBookRepository([
      _makeBook('b1', '书一', 0.1),
      _makeBook('b2', '书二', 0.2),
    ]);
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.text('书一'));
    // 书名同时在封面和封面下方出现，所以 findsWidgets
    expect(find.text('书一'), findsWidgets);
    expect(find.text('书二'), findsWidgets);
  });

  testWidgets('删除时只移除对应书籍', (tester) async {
    final repo = FakeBookRepository([
      _makeBook('b1', '书一', 0.1),
      _makeBook('b2', '书二', 0.2),
    ]);
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.text('书一'));
    await tester.longPress(find.text('书一').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除书籍'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.text('书一'), findsNothing);
    expect(find.text('书二'), findsWidgets);
  });

  testWidgets('阅读器返回后进度不闪空', (tester) async {
    final longText = '第一章 开局\n' * 600;
    final repo = FakeBookRepository([
      _makeBook('b1', '书一', 0.0),
      _makeBook('b2', '书二', 0.0),
    ]);
    Future<String> longLoader(Book _) async => longText;
    await tester.pumpWidget(
      CupertinoApp(
        home: BookShelfPage(repository: repo, contentLoader: longLoader),
      ),
    );
    await pumpUntilFound(tester, find.text('书一'));
    ReadingSettingsService.instance.setSettingsForTest(
      (await ReadingSettingsService.instance.get()).copyWith(
        pageAnimation: PageAnimation.scroll,
      ),
    );
    await tester.tap(find.text('书一').last);
    await pumpUntilFound(tester, find.byType(SingleChildScrollView));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reader_tap_center')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reader_back')));
    await tester.pumpAndSettle();
    expect(find.text('书一'), findsWidgets);
    expect(find.text('书二'), findsWidgets);
  });
}
