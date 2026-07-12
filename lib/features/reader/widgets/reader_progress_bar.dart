library;

import 'package:flutter/cupertino.dart';

/// 沉浸态底部进度信息：
///  - 左下：全书阅读百分比；
///  - 右下：当前页/总页（或当前章/总章）。
class ReaderProgressBar extends StatelessWidget {
  final double progress; // 0..1 全书进度
  final String rightLabel; // 如 "12 / 340" 或 "3 / 28 章"

  const ReaderProgressBar({
    super.key,
    required this.progress,
    required this.rightLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = CupertinoColors.label.resolveFrom(context).withValues(alpha: 0.7);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text('${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: textColor, fontSize: 12)),
            const Spacer(),
            Text(rightLabel, style: TextStyle(color: textColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
