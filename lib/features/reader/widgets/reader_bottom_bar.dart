library;

import 'package:flutter/cupertino.dart';

/// 阅读器底部主工具栏（沉浸态隐藏，点击中间显出）：
/// 第一层：上一章 / 章节进度 Slider（可拖动，拖动中显示百分比和章节位置）/ 下一章；
/// 第二层 4 入口：目录 / 夜间 / 设置 / 听书。
class ReaderBottomBar extends StatelessWidget {
  final double chapterProgress; // 0..1 当前章节内进度
  final String chapterPositionLabel; // 如 "第 3 / 28 章"
  final void Function() onPrevChapter;
  final void Function() onNextChapter;
  final void Function(double) onChapterSliderChanged;
  final void Function() onDirectory;
  final void Function() onNight;
  final void Function() onSettings;
  final void Function() onListening;

  const ReaderBottomBar({
    super.key,
    required this.chapterProgress,
    required this.chapterPositionLabel,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onChapterSliderChanged,
    required this.onDirectory,
    required this.onNight,
    required this.onSettings,
    required this.onListening,
  });

  @override
  Widget build(BuildContext context) {
    final fg = CupertinoColors.label.resolveFrom(context);
    final line = CupertinoColors.separator.resolveFrom(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: CupertinoColors.systemBackground.resolveFrom(context),
      padding: const EdgeInsets.only(bottom: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一层：上一章 / Slider / 下一章
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: onPrevChapter,
                    child: const Icon(CupertinoIcons.back, size: 22),
                  ),
                  Expanded(
                    child: CupertinoSlider(
                      value: chapterProgress.clamp(0.0, 1.0),
                      onChanged: onChapterSliderChanged,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: onNextChapter,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4(-1.0, 0, 0, 0,
                          0, 1.0, 0, 0,
                          0, 0, 1.0, 0,
                          0, 0, 0, 1.0),
                      child: const Icon(CupertinoIcons.back, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(chapterPositionLabel, style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11)),
            ),
            const SizedBox(height: 4),
            // 第二层：4 入口
            Container(height: 0.5, color: line),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Entry(icon: CupertinoIcons.list_bullet, label: '目录', onTap: onDirectory),
                _Entry(icon: CupertinoIcons.moon, label: '夜间', onTap: onNight),
                _Entry(icon: CupertinoIcons.slider_horizontal_3, label: '设置', onTap: onSettings),
                _Entry(icon: CupertinoIcons.volume_up, label: '听书', onTap: onListening),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  final IconData icon;
  final String label;
  final void Function() onTap;
  const _Entry({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = CupertinoColors.label.resolveFrom(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: fg),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: fg, fontSize: 11)),
        ],
      ),
    );
  }
}
