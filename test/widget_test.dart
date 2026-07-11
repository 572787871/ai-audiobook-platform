import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:ai_audiobook_platform/features/library/pages/library_page.dart';
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

void main() {
  testWidgets('空书库首页：标题/文案/四个导入入口/无右下角 FAB', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: LibraryPage(repository: FakeBookRepository()),
      ),
    );

    // 等待 _loadBooks 异步完成，空状态出现
    await pumpUntilFound(tester, find.text('开始听第一本书'));

    // 顶部标题与空状态引导文案
    expect(find.text('书库'), findsOneWidget);
    expect(find.text('开始听第一本书'), findsOneWidget);
    expect(find.text('导入小说，让 AI 为你实时朗读'), findsOneWidget);

    // 四个导入入口卡片及副标题
    expect(find.text('本地文件'), findsOneWidget);
    expect(find.text('粘贴文本'), findsOneWidget);
    expect(find.text('扫描文字'), findsOneWidget);
    expect(find.text('从其他 App 导入'), findsOneWidget);
    expect(find.text('TXT、EPUB、PDF'), findsOneWidget);
    expect(find.text('输入或粘贴小说内容'), findsOneWidget);
    expect(find.text('从图片或文档中识别'), findsOneWidget);
    expect(find.text('通过系统分享菜单添加'), findsOneWidget);

    // 首页本身是导入入口，不应再出现右下角 FloatingActionButton
    expect(find.byKey(const Key('import_fab')), findsNothing);
  });

  testWidgets('点击「粘贴文本」入口弹出后续版本提示（不开发该功能）', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: LibraryPage(repository: FakeBookRepository()),
      ),
    );
    await pumpUntilFound(tester, find.text('粘贴文本'));

    // 点击「粘贴文本」卡片
    await tester.tap(find.text('粘贴文本'));
    await tester.pumpAndSettle();

    // 提示将在后续版本加入
    expect(find.text('该功能将在后续版本加入'), findsOneWidget);
  });

  testWidgets('有书时显示「书库」分区，点击进入 Book Detail', (tester) async {
    final book = Book(
      id: 'book-1',
      title: '测试小说',
      originalFileName: '测试小说.txt',
      fileType: BookFileType.txt,
      originalPath: '/tmp/测试小说.txt',
      contentPath: '/tmp/测试小说.content.txt',
      fileSize: 1024,
      characterCount: 10000,
      encoding: 'UTF-8',
      createdAt: DateTime(2026, 7, 11),
      updatedAt: DateTime(2026, 7, 11),
      lastReadOffset: 0,
      readingProgress: 0,
      parseStatus: BookParseStatus.ready,
      chapterCount: 0,
      coverPath: null,
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: LibraryPage(repository: FakeBookRepository([book])),
      ),
    );

    await pumpUntilFound(tester, find.text('测试小说'));

    // 顶部导入入口仍在
    expect(find.text('书库'), findsWidgets);
    expect(find.text('本地文件'), findsOneWidget);
    // 书库分区标题
    expect(find.text('书库'), findsWidgets);
    // 书籍卡片
    expect(find.text('测试小说'), findsOneWidget);
    // 不应再有「最近添加」
    expect(find.text('最近添加'), findsNothing);
    // 无右下角 FAB
    expect(find.byKey(const Key('import_fab')), findsNothing);

    // 点击书籍卡片 -> 进入 Book Detail（非重新导入）
    await tester.ensureVisible(find.text('测试小说'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试小说'));
    await tester.pumpAndSettle();
    expect(find.text('书籍详情'), findsOneWidget);
    expect(find.text('格式：TXT'), findsOneWidget);

    // 返回首页后，点击「书库」分区标题进入书架页
    await tester.pageBack();
    await tester.pumpAndSettle();
    final shelfTitle = find.text('书库');
    await tester.ensureVisible(shelfTitle.last);
    await tester.pumpAndSettle();
    await tester.tap(shelfTitle.last);
    await tester.pumpAndSettle();
    // 书架页导航栏标题也是「书库」
    expect(find.text('书库'), findsWidgets);

    // 返回 -> 回到首页（导入入口 + 已导入书籍仍在）
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('书库'), findsWidgets);
  });
}
