library;

import 'package:flutter/cupertino.dart';

/// 阅读器顶部工具栏（沉浸态隐藏，点击中间显出）：
///  - 左：返回（兼容 iOS 左边缘右滑返回，由外层 PopScope 处理）；
///  - 中：当前书名 + 当前章节名小标题；
///  - 右：听书入口 / 分享 / 更多菜单。
/// 更多菜单包含：书籍详情（已接）、重命名 / 搜索 / 书签（未实现，显示真实状态）、删除书籍（已接）。
class ReaderTopBar extends StatelessWidget {
  final String bookTitle;
  final String? chapterTitle;
  final void Function() onBack;
  final void Function() onListening;
  final void Function() onShare;
  final void Function() onBookDetail;
  final void Function() onRename;
  final void Function() onSearch;
  final void Function() onBookmark;
  final void Function() onDelete;

  const ReaderTopBar({
    super.key,
    required this.bookTitle,
    this.chapterTitle,
    required this.onBack,
    required this.onListening,
    required this.onShare,
    required this.onBookDetail,
    required this.onRename,
    required this.onSearch,
    required this.onBookmark,
    required this.onDelete,
  });

  void _showMore(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(bookTitle),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              onBookDetail();
            },
            child: const Text('书籍详情'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              onRename();
            },
            child: const Text('重命名'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              onSearch();
            },
            child: const Text('搜索'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              onBookmark();
            },
            child: const Text('书签'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
            child: const Text('删除书籍'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = CupertinoColors.label.resolveFrom(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: CupertinoColors.systemBackground.resolveFrom(context),
      padding: EdgeInsets.only(left: 12, top: MediaQuery.of(context).padding.top),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              CupertinoButton(
                key: const Key('reader_back'),
                padding: const EdgeInsets.only(left: 16, right: 8),
                minimumSize: Size.zero,
                onPressed: onBack,
                child: const Icon(CupertinoIcons.back, size: 26),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bookTitle,
                        style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (chapterTitle != null)
                      Text(chapterTitle!,
                          style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                onPressed: onListening,
                child: const Icon(CupertinoIcons.volume_up, size: 22),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                onPressed: onShare,
                child: const Icon(CupertinoIcons.share, size: 22),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                onPressed: () => _showMore(context),
                child: const Icon(CupertinoIcons.ellipsis, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
