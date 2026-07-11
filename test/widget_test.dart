import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:ai_audiobook_platform/features/reader/services/reading_settings_service.dart';
import 'package:ai_audiobook_platform/features/library/pages/library_page.dart';
import 'package:ai_audiobook_platform/features/library/pages/book_shelf_page.dart';
import 'package:ai_audiobook_platform/features/library/pages/book_detail_page.dart';
import 'package:ai_audiobook_platform/features/reader/pages/reader_page.dart';
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
  // 注入阅读器设置目录，避免 flutter test 环境下 path_provider 触发进程崩溃，
  // 从而让 ReaderPage._init 能正常完成正文加载。
  setUpAll(() {
    ReadingSettingsService.instance.setDirForTest(Directory.systemTemp);
  });

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
    expect(find.text('暂无已导入书籍'), findsOneWidget);
    expect(find.text('测试小说'), findsNothing);
    expect(find.byKey(const Key('import_fab')), findsNothing);
  });

  testWidgets('首页只显示“书库”入口卡片，不直接展开书籍列表',
      (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    await tester.pumpWidget(
      CupertinoApp(home: LibraryPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.text('书库'));
    expect(find.text('已导入 1 本书'), findsOneWidget);
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
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('阅读中'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
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

  testWidgets('编辑模式删除书籍后当前书架立即移除卡片', (tester) async {
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

  testWidgets('ReaderPage 顶部有返回按钮', (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    await tester.pumpWidget(
      CupertinoApp(home: ReaderPage(book: repo.books.first, repository: repo)),
    );
    await pumpUntilFound(tester, find.text('返回'));
    expect(find.text('返回'), findsWidgets);
    expect(find.text('测试小说'), findsOneWidget);
  });

  testWidgets('点击返回前会保存进度', (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    await tester.pumpWidget(
      CupertinoApp(home: ReaderPage(book: repo.books.first, repository: repo)),
    );
    await pumpUntilFound(tester, find.text('返回'));
    final before = repo.savedCount;
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(repo.savedCount, greaterThan(before));
  });

  testWidgets('阅读后返回详情页进度立即更新', (tester) async {
    // 注入内存正文（多页），不依赖真实磁盘读取 / path_provider
    final longText = '第一章 开局\n' * 600;
    // 初始进度 0（尚未阅读）
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    await tester.pumpWidget(
      CupertinoApp(
        home: BookDetailPage(
          book: repo.books.first,
          repository: repo,
          // 详情页透传 contentLoader 给阅读器
          contentLoader: (_) async => longText,
          // 进入阅读器时定位到第 1 页（模拟“读到这里”，不依赖手势）
          initialPageIndex: 1,
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('书籍详情'));
    final savedBefore = repo.savedCount;
    expect(repo.books.first.readingProgress, 0.0);
    // 详情页初始显示“0%”
    expect(find.text('0%'), findsWidgets);

    // 进入阅读器，并指定起始阅读页为第 1 页（模拟“读到这里”，不依赖手势）
    await tester.tap(find.text('继续阅读'));
    await pumpUntilFound(tester, find.byKey(const Key('reader_back')));

    // 手动推进帧，覆盖注入 loader 异步返回与页面动画（绕开加载指示器持续动画）
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // 加载指示器应已停止，证明正文加载完成
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    // 正文加载完成，出现可滚动正文
    await pumpUntilFound(tester, find.byType(SingleChildScrollView));

    // 点返回：阅读器内部先保存进度（写入第 1 页位置），再 pop updatedBook 给详情页
    await tester.tap(find.byKey(const Key('reader_back')));
    await tester.pumpAndSettle();

    // 返回后仍在详情页（原地刷新，未重新进入）
    expect(find.text('书籍详情'), findsOneWidget);
    // 返回时已触发 repository.save
    expect(repo.savedCount, greaterThan(savedBefore));
    // 阅读进度已写入仓储且大于 0（确实定位到了第 1 页）
    expect(repo.books.first.readingProgress, greaterThan(0.0));
    // 详情页进度显示立即更新（不再显示旧的“0%”，出现新的百分比）
    expect(find.text('0%'), findsNothing);
    expect(find.textContaining('%'), findsWidgets);
  });

  testWidgets('删除最后一本后显示空书架状态', (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    await tester.pumpWidget(
      CupertinoApp(home: BookShelfPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.byKey(const Key('book_b1')));
    await tester.longPress(find.byKey(const Key('book_b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.text('书架空空如也，去首页导入吧'), findsOneWidget);
    expect(find.text('测试小说'), findsNothing);
  });

  testWidgets('从书架返回首页后数量同步为 0', (tester) async {
    final repo = FakeBookRepository([_makeBook('b1', '测试小说', 0.0)]);
    await tester.pumpWidget(
      CupertinoApp(home: LibraryPage(repository: repo)),
    );
    await pumpUntilFound(tester, find.text('已导入 1 本书'));
    await tester.ensureVisible(find.byKey(const Key('shelf_entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_entry')));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.byKey(const Key('book_b1')));
    await tester.longPress(find.byKey(const Key('book_b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('暂无已导入书籍'));
    expect(find.text('已导入 1 本书'), findsNothing);
  });
}
