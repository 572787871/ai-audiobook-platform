library;

import 'package:flutter/cupertino.dart';
import '../engine/chapter_parser.dart';

/// 阅读目录页：展示章节列表，点击跳转至对应章节起始字符偏移。
class DirectoryPage extends StatelessWidget {
  final ChapterList chapters;
  final int currentChapterIndex;
  final void Function(int globalOffset) onJump;

  const DirectoryPage({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('目录'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('关闭'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: ListView.separated(
          itemCount: chapters.chapters.length,
          separatorBuilder: (_, _) => Container(height: 1, color: CupertinoColors.separator),
          itemBuilder: (_, i) {
            final ch = chapters.chapters[i];
            final active = i == currentChapterIndex;
            return CupertinoListTile(
              title: Text(
                ch.title,
                style: TextStyle(
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: active ? const Icon(CupertinoIcons.location_fill, size: 16) : null,
              onTap: () {
                Navigator.of(context).pop();
                onJump(ch.start);
              },
            );
          },
        ),
      ),
    );
  }
}
