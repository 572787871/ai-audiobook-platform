library;

import 'package:flutter/cupertino.dart';
import '../engine/reader_controller.dart';
import '../services/reading_settings_service.dart';

/// 阅读器底部工具栏（独立组件）：进度、设置入口、听书入口。
class ReaderToolbar extends StatelessWidget {
  final ReaderController controller;
  final ReadingSettings settings;
  final bool listening;
  final void Function() onOpenSettings;
  final void Function() onToggleListening;

  const ReaderToolbar({
    super.key,
    required this.controller,
    required this.settings,
    required this.listening,
    required this.onOpenSettings,
    required this.onToggleListening,
  });

  @override
  Widget build(BuildContext context) {
    final progress = controller.position.readingProgress;
    final themeText = CupertinoColors.label.resolveFrom(context);
    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onOpenSettings,
              child: const Icon(CupertinoIcons.slider_horizontal_3, size: 24),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: themeText),
            ),
            const Spacer(),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onToggleListening,
              child: Icon(
                listening ? CupertinoIcons.pause : CupertinoIcons.volume_up,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
