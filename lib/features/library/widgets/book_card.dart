import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../models/book.dart';
import '../../../shared/utils/file_size_formatter.dart';
import '../models/book_file_type.dart';

/// 书库书籍卡片
class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration,
          child: Row(
            children: [
              // 封面占位
              Container(
                width: 52,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.iconBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.doc_text,
                    size: 26,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${book.fileType.label} · ${FileSizeFormatter.format(book.fileSize)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final time = DateFormat('yyyy-MM-dd HH:mm').format(book.createdAt);
    if (book.fileType == BookFileType.txt && book.characterCount != null) {
      return '${book.characterCount} 字 · $time';
    }
    return time;
  }
}
