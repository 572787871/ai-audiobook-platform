import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../models/book.dart';
import '../models/book_file_type.dart';
import '../models/book_parse_status.dart';
import '../services/book_repository.dart';
import '../../../shared/utils/file_size_formatter.dart';
import '../../reader/pages/reader_page.dart';

/// 书籍详情页
class BookDetailPage extends StatelessWidget {
  const BookDetailPage({super.key, required this.book, this.repository});

  final Book book;
  final BookRepositoryBase? repository;

  BookRepositoryBase get _repo => repository ?? BookRepository.instance;

  @override
  Widget build(BuildContext context) {
    final isTxt = book.fileType == BookFileType.txt;
    final created = DateFormat('yyyy-MM-dd HH:mm').format(book.createdAt);

    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('书籍详情'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.ellipsis, size: 22),
          onPressed: () => _showMenu(context),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.horizontalPadding),
          children: [
            // 标题
            Text(
              book.title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '格式：${book.fileType.label}',
              style: const TextStyle(fontSize: 15, color: AppTheme.secondaryText),
            ),
            const SizedBox(height: 20),

            // 信息卡片
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  _row('文件大小', FileSizeFormatter.format(book.fileSize)),
                  _row('字符数', isTxt ? '${book.characterCount ?? 0} 字' : '—'),
                  _row('导入时间', created),
                  _row('上次阅读', DateFormat('yyyy-MM-dd HH:mm').format(book.updatedAt)),
                  _row('解析状态', book.parseStatus.label),
                  _row('章节状态', isTxt ? '未分章' : '不可用'),
                  _row('AI 模型', '未下载'),
                  if (isTxt && book.encoding != null)
                    _row('编码', book.encoding!),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 操作按钮
            if (isTxt) ...[
              _actionButton(
                context,
                '继续阅读',
                onPressed: () => _continueReading(context),
              ),
              const SizedBox(height: 12),
              _actionButton(
                context,
                '开始听书',
                onPressed: () => _toast(context, 'AI 模型将在后续阶段加入'),
              ),
            ] else ...[
              _disabledButton('继续阅读（等待解析）'),
              const SizedBox(height: 12),
              _disabledButton('开始听书（等待解析）'),
            ],
            const SizedBox(height: 16),

            // 阅读统计
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  _row('阅读进度',
                      '${(book.readingProgress * 100).round()}%'),
                  _row('当前章节', book.lastReadChapter ?? '未开始'),
                  _row('阅读时长',
                      '${(book.readingTimeSec / 60).floor()} 分钟'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _continueReading(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => ReaderPage(book: book, repository: _repo)),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 15, color: AppTheme.secondaryText)),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, color: AppTheme.primaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context, String title,
      {required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        onPressed: onPressed,
        child: Text(title),
      ),
    );
  }

  Widget _disabledButton(String title) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        onPressed: null,
        color: AppTheme.iconBackground,
        child: Text(title,
            style: const TextStyle(color: AppTheme.secondaryText)),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('重命名'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _rename(context);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除书籍'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _confirmDelete(context);
            },
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

  void _confirmDelete(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除书籍'),
        content: const Text('确定要删除这本书吗？此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _repo.delete(book.id);
              if (context.mounted) {
                Navigator.of(context).pop(); // 返回书库
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: book.title);
    final result = await showCupertinoDialog<String?>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('重命名'),
        content: CupertinoTextField(controller: controller),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('确定'),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != book.title) {
      await _repo.save(book.copyWith(title: result, updatedAt: DateTime.now()));
    }
  }

  void _toast(BuildContext context, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('好的'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}
