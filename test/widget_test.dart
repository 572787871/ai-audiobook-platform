import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:ai_audiobook_platform/features/library/pages/library_page.dart';
import 'package:ai_audiobook_platform/features/library/pages/book_shelf_page.dart';
import 'package:ai_audiobook_platform/features/library/models/book.dart';
import 'package:ai_audiobook_platform/features/library/models/book_file_type.dart';
import 'package:ai_audiobook_platform/features/library/models/book_parse_status.dart';
import 'fake_book_repository.dart';

/// 有限次数推进帧，直到 [finder] 出现；超时抛 TestFailure。
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

Book _makeBook(String id, String title, double progress) => Book(
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
      lastReadOffset: 0,
      readingProgress: progress,
      parseStatus: BookParseStatus.ready,
      chapterCount: 0,
      coverPath: null,
    );

void main() {
  testWidgets('空书库首页：标题/四个导入入口/无 FAB', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(home: LibraryPage(repository: FakeBookRepository())),
    );
    await pumpUntilFound(tester, find.text('开始听第一本书'));
    expect(find.text('书库'), findsWidgets);
    expect(find.text('开始听第一本书'), findsOneWidget);
    expect(find.text('导入小说，让 AI 为你实时朗读'), findsOneWidget);
    expect(find.text('本地文件'), findsOneWidget);
    expect(find.text('粘贴文本'), findsOneWidget);
    expect(find.text('扫描文字'), findsOneWidget);
    expect(find.text('从其他 App 导入'), findsOneWidget);
    // 书库入口卡片存在，副标题为空状态
    expect(find.text('暂无已导入书籍'), findsOneWidget);
    // 首页不直接显示具体书籍
    expect(find.text('测试小说'), findsNothing);
    expect(find.byKey(const Key('import_fab')), findsNothing);
  });

  testWidgets('首页只显示“书库”入口卡片，不直接展开书籍列表', (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    await tester.pumpWidget(
      CupertinoApp(home: LibraryPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.text('书库'));
    expect(find.text('已导入 1 本书'), findsOneWidget);
    // 首页不应直接显示书籍书名
    expect(find.text('测试小说'), findsNothing);
  });

  testWidgets('点击书库入口进入独立 BookShelfPage', (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    await tester.pumpWidget(
      CupertinoApp(home: LibraryPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.text('书库'));
    await tester.ensureVisible(find.byKey(const Key('shelf_entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_entry')));
    await tester.pumpAndSettle();
    // 独立书架页：分类栏
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('阅读中'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget); // 分类栏标签
    // 书籍以网格封面显示（书名出现 2 次：封面+下方）
    expect(find.text('测试小说'), findsWidgets);
  });

  testWidgets('书库页面以网格封面显示并展示阅读进度', (tester) async {
    final repo = FakeBookRepository([
      _makeBook('b1', '小说A', 0.0),
      _makeBook('b2', '小说B', 0.36),
      _makeBook('b3', '小说C', 1.0),
    ]);
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.byKey(const Key('book_b1')));
    expect(find.text('未开始'), findsWidgets);
    final scrollable = find.byType(Scrollable);
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('已读 36%'), findsOneWidget);
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('已完成'), findsAtLeastNWidgets(2));
  });

  testWidgets('点击书籍封面进入详情页', (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.byKey(const Key('book_b1')));
    await tester.ensureVisible(find.byKey(const Key('book_b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_b1')));
    await tester.pumpAndSettle();
    expect(find.text('书籍详情'), findsOneWidget);
    expect(find.text('格式：TXT'), findsOneWidget);
    expect(find.text('阅读进度'), findsOneWidget);
    expect(find.text('上次阅读'), findsOneWidget);
  });

  testWidgets('无书时 bookshelf 显示空状态', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: FakeBookRepository())),
    );
    await pumpUntilFound(tester, find.text('书架空空如也，去首页导入吧'));
    expect(find.text('书架空空如也，去首页导入吧'), findsOneWidget);
  });

  testWidgets('删除后书籍从书架消失', (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.byKey(const Key('book_b1')));
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('book_b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除 1 本书？'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.text('测试小说'), findsNothing);
  });
}
