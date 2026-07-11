import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:ai_audiobook_platform/features/reader/services/reading_settings_service.dart';
import 'package:ai_audiobook_platform/features/reader/widgets/reader_pager.dart';

final _pages = List.generate(5, (i) => Center(child: Text('P$i')));

Future<void> _pump(WidgetTester t, PageAnimation anim) async {
  await t.pumpWidget(CupertinoApp(
    home: ReaderPager(
      pages: _pages,
      animation: anim,
      onPageChanged: (_) {},
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => ReadingSettingsService.instance.setDirForTest(Directory.systemTemp));

  testWidgets('四种翻页模式都能正常构建切换', (tester) async {
    for (final a in PageAnimation.values) {
      await _pump(tester, a);
      expect(find.byType(ReaderPager), findsOneWidget);
    }
  });

  testWidgets('仿真模式拖动超过阈值进入下一页', (tester) async {
    await _pump(tester, PageAnimation.curl);
    await tester.dragFrom(const Offset(400, 300), const Offset(120, 0));
    await tester.pumpAndSettle();
    // 拖拽从右向左超过阈值 -> 翻到下一页（page changed）
    expect(find.text('P1'), findsWidgets);
  });

  testWidgets('仿真模式拖动不足阈值会回弹', (tester) async {
    await _pump(tester, PageAnimation.curl);
    await tester.dragFrom(const Offset(400, 300), const Offset(380, 0));
    await tester.pumpAndSettle();
    // 不足阈值回弹，仍停留在第 0 页
    expect(find.text('P0'), findsWidgets);
  });

  testWidgets('点击中间区域显示/隐藏工具栏回调', (tester) async {
    var toggled = 0;
    await tester.pumpWidget(CupertinoApp(
      home: ReaderPager(
        pages: _pages,
        animation: PageAnimation.curl,
        onToggleToolbar: () => toggled++,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(toggled, 1);
  });
}
