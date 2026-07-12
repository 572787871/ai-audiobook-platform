import 'package:flutter/cupertino.dart';

/// 底部导入方式 Action Sheet。
///
/// 本阶段仅「本地文件」真实可用；其余入口点击后回调 [onUnsupported]。
class ImportActionSheet {
  ImportActionSheet._();

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onLocalFile,
    required VoidCallback onUnsupported,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('导入小说'),
        message: const Text('选择导入方式'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => onLocalFile(),
              );
            },
            child: const Text('本地文件'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => onUnsupported(),
              );
            },
            child: const Text('粘贴文本'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => onUnsupported(),
              );
            },
            child: const Text('扫描文字'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => onUnsupported(),
              );
            },
            child: const Text('从其他 App 导入'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }
}
