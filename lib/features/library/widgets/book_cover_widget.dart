import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../models/book.dart';
import '../services/book_cover_service.dart';
import '../../../theme/app_theme.dart';

/// 封面组件：渐变底色 + 书名 + 可选进度条
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
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // 纹理
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CoverTexturePainter(colors.last),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          book.title,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                    // 书脊
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: colors.last.withValues(alpha: 0.3),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            bottomLeft: Radius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryText,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          if (book.lastReadChapter != null && book.lastReadChapter!.isNotEmpty)
            Text(
              book.lastReadChapter!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.secondaryText,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            _progressLabel,
            style: TextStyle(
              fontSize: 12,
              color: book.readingProgress >= 1
                  ? CupertinoColors.activeBlue
                  : AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  String get _progressLabel {
    final pct = (book.readingProgress * 100).round();
    if (book.readingProgress <= 0) return '未开始';
    if (pct >= 100) return '已完成';
    return '已读 $pct%';
  }
}

class _CoverTexturePainter extends CustomPainter {
  final Color baseColor;
  _CoverTexturePainter(this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 20) {
      for (var y = 0.0; y < size.height; y += 20) {
        if ((x + y) % 40 < 20) {
          canvas.drawCircle(Offset(x + 2, y + 2), 1.5, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
