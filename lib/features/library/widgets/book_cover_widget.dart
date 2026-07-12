import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../models/book.dart';
import '../services/book_cover_service.dart';

/// 实体书封面卡片（微信读书 / Apple Books 风格）。
///
/// 渐变底色 + 书名 + 可选作者 + 底部蓝色阅读进度条。
class BookCoverWidget extends StatelessWidget {
  const BookCoverWidget({
    super.key,
    required this.book,
    this.showProgress = true,
    this.onTap,
    this.onLongPress,
  });

  final Book book;
  final bool showProgress;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = BookCoverService.colorsFor(book);
    final pct = (book.readingProgress * 100).round();
    final progressLabel = book.readingProgress <= 0
        ? '未开始'
        : pct >= 100
        ? '已完成'
        : '已读 $pct%';
    final hasAuthor = book.author != null && book.author!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  // 书脊效果
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(
                      left: BorderSide(color: Color(0x2E000000), width: 5),
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          book.title,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (hasAuthor)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            book.author!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xD9FFFFFF),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 底部蓝色阅读进度条
                if (showProgress)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 3,
                          color: Colors.black.withValues(alpha: 0.18),
                        ),
                        Container(height: 3, color: CupertinoColors.activeBlue),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            progressLabel,
            maxLines: 1,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
          ),
        ],
      ),
    );
  }
}
