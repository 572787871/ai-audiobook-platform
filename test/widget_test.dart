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
  testWidgets('空书库首页结构正确且可触发导入入口', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: LibraryPage(repository: FakeBookRepository()),
      ),
    );

    // 等待 _loadBooks 异步完成，空状态出现
    await pumpUntilFound(tester, find.text('开始听第一本书'));

    // 顶部标题与空状态
    expect(find.text('书库'), findsOneWidget);
    expect(find.text('开始听第一本书'), findsOneWidget);
    expect(find.text('导入小说，让 AI 为你实时朗读'), findsOneWidget);

    // 空状态导入卡片及副标题
    expect(find.text('本地文件'), findsOneWidget);
    expect(find.text('粘贴文本'), findsOneWidget);
    expect(find.text('扫描文字'), findsOneWidget);
    expect(find.text('从其他 App 导入'), findsOneWidget);
    expect(find.text('TXT、EPUB、PDF 等格式'), findsOneWidget);
    expect(find.text('输入或粘贴小说内容'), findsOneWidget);
    expect(find.text('从图片或文档中识别'), findsOneWidget);
    expect(find.text('通过系统分享菜单添加'), findsOneWidget);

    // 右下角导入按钮
    expect(find.byKey(const Key('import_fab')), findsOneWidget);

    // 点击「导入小说」弹出 Action Sheet
    await tester.tap(find.byKey(const Key('import_fab')));
    await tester.pumpAndSettle();
    expect(find.text('选择导入方式'), findsOneWidget);
    expect(find.text('本地文件'), findsWidgets);
    expect(find.text('粘贴文本'), findsWidgets);
    expect(find.text('扫描文字'), findsWidgets);
    expect(find.text('从其他 App 导入'), findsWidgets);

    // 选择「粘贴文本」（本期未实现）→ 提示将在后续版本加入
    final actions = find.byType(CupertinoActionSheetAction);
    await tester.tap(actions.at(1));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('该功能将在后续版本加入'), findsOneWidget);
  });

  testWidgets('有书时显示书籍列表和导入按钮', (tester) async {
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

    // 书籍卡片与导入按钮都存在
    expect(find.text('测试小说'), findsOneWidget);
    expect(find.text('最近添加'), findsOneWidget);
    expect(find.byKey(const Key('import_fab')), findsOneWidget);
  });
}
