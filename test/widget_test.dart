import 'package:flutter_test/flutter_test.dart';
import 'package:ai_audiobook_platform/app.dart';

void main() {
  testWidgets('App should launch and show library page', (tester) async {
    await tester.pumpWidget(const AudiobookApp());

    // 验证页面标题
    expect(find.text('书库'), findsOneWidget);
    expect(find.text('开始听第一本书'), findsOneWidget);
    expect(find.text('导入小说，让 AI 为你实时朗读'), findsOneWidget);

    // 验证导入选项
    expect(find.text('本地文件'), findsOneWidget);
    expect(find.text('粘贴文本'), findsOneWidget);
    expect(find.text('扫描文字'), findsOneWidget);
    expect(find.text('从其他 App 导入'), findsOneWidget);

    // 验证副标题
    expect(find.text('TXT、EPUB、PDF 等格式'), findsOneWidget);
    expect(find.text('输入或粘贴小说内容'), findsOneWidget);
    expect(find.text('从图片或文档中识别'), findsOneWidget);
    expect(find.text('通过系统分享菜单添加'), findsOneWidget);

    // 点击导入卡片，弹出提示
    await tester.tap(find.text('本地文件'));
    await tester.pumpAndSettle();
    expect(find.text('功能将在下一阶段加入'), findsOneWidget);
  });
}
