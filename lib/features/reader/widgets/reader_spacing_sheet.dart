library;

import 'package:flutter/cupertino.dart';
import '../services/reading_settings_service.dart';

/// 间距设置二级面板（从底部弹出）：行距 / 段距 / 左右边距 / 上下边距 / 首行缩进。
/// 全部实时生效，外部负责按 characterOffset 恢复阅读位置。
class ReaderSpacingSheet extends StatelessWidget {
  final ReadingSettings settings;
  final void Function(ReadingSettings) onChanged;

  const ReaderSpacingSheet({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final line = CupertinoColors.separator.resolveFrom(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('间距设置'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('完成'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            _Row(
              label: '行距',
              value: settings.lineHeight.toStringAsFixed(1),
              child: CupertinoSlider(
                value: settings.lineHeight,
                min: 1.0,
                max: 2.4,
                onChanged: (v) => onChanged(settings.copyWith(lineHeight: v)),
              ),
            ),
            _Row(
              label: '段距',
              value: settings.paragraphSpacing.toStringAsFixed(0),
              child: CupertinoSlider(
                value: settings.paragraphSpacing,
                min: 0,
                max: 32,
                onChanged: (v) => onChanged(settings.copyWith(paragraphSpacing: v)),
              ),
            ),
            _Row(
              label: '左右边距',
              value: settings.horizontalMargin.toStringAsFixed(0),
              child: CupertinoSlider(
                value: settings.horizontalMargin,
                min: 8,
                max: 48,
                onChanged: (v) => onChanged(settings.copyWith(horizontalMargin: v)),
              ),
            ),
            _Row(
              label: '上下边距',
              value: settings.verticalMargin.toStringAsFixed(0),
              child: CupertinoSlider(
                value: settings.verticalMargin,
                min: 0,
                max: 48,
                onChanged: (v) => onChanged(settings.copyWith(verticalMargin: v)),
              ),
            ),
            _Row(
              label: '首行缩进',
              value: '${settings.firstLineIndent.toStringAsFixed(0)} 字',
              child: CupertinoSlider(
                value: settings.firstLineIndent,
                min: 0,
                max: 4,
                divisions: 4,
                onChanged: (v) => onChanged(settings.copyWith(firstLineIndent: v)),
              ),
            ),
            Container(height: 0.5, color: line),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Widget child;
  const _Row({required this.label, required this.value, required this.child});

  @override
  Widget build(BuildContext context) {
    final fg = CupertinoColors.label.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: TextStyle(color: fg)),
            const Spacer(),
            Text(value, style: TextStyle(color: fg.withValues(alpha: 0.6))),
          ]),
          child,
        ],
      ),
    );
  }
}
