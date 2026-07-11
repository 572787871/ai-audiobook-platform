import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../../../theme/app_theme.dart';
import '../models/book.dart';
import '../models/book_file_type.dart';
import '../services/book_repository.dart';
import '../services/book_cover_service.dart';
import 'book_detail_page.dart';
import '../../reader/pages/reader_page.dart';

/// 书架页：2 列瀑布流，每本书像实体书。
class BookShelfPage extends StatefulWidget {
  final BookRepositoryBase? repository;

  const BookShelfPage({super.key, this.repository});

  @override
  State<BookShelfPage> createState() => _BookShelfPageState();
}

class _BookShelfPageState extends State<BookShelfPage> {
  final List<Book> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final books = await (widget.repository ?? BookRepository.instance).loadAll();
    books.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (mounted) {
      setState(() {
        _books
          ..clear()
          ..addAll(books);
        _loading = false;
      });
    }
  }

  Future<void> _rename(Book book) async {
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
      final updated = book.copyWith(title: result, updatedAt: DateTime.now());
      await (widget.repository ?? BookRepository.instance).save(updated);
      _load();
    }
  }

  Future<void> _delete(Book book) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除书籍'),
        content: const Text('确定要删除这本书吗？此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await (widget.repository ?? BookRepository.instance).delete(book.id);
      _load();
    }
  }

  void _openDetail(Book book) {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => BookDetailPage(book: book)),
    );
  }

  void _continueReading(Book book) {
    if (book.fileType != BookFileType.txt) {
      _toast('该书暂未解析，无法阅读');
      return;
    }
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => ReaderPage(book: book)),
    );
  }

  void _toast(String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(msg),
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

  void _showMenu(Book book) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _continueReading(book);
            },
            child: const Text('继续阅读'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openDetail(book);
            },
            child: const Text('书籍详情'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _rename(book);
            },
            child: const Text('重命名'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _delete(book);
            },
            child: const Text('删除'),
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('书库'),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _books.isEmpty
                ? const Center(
                    child: Text('还没有书籍，去首页导入吧',
                        style: TextStyle(color: AppTheme.secondaryText)),
                  )
                : _buildShelf(),
      ),
    );
  }

  Widget _buildShelf() {
    final left = <Book>[];
    final right = <Book>[];
    for (var i = 0; i < _books.length; i++) {
      if (i.isEven) {
        left.add(_books[i]);
      } else {
        right.add(_books[i]);
      }
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: left.map(_bookCard).toList())),
            const SizedBox(width: 12),
            Expanded(child: Column(children: right.map(_bookCard).toList())),
          ],
        ),
      ],
    );
  }

  Widget _bookCard(Book book) {
    final colors = BookCoverService.colorsFor(book);
    final pct = (book.readingProgress * 100).round();
    final progressLabel = book.readingProgress <= 0
        ? '未开始'
        : pct >= 100
            ? '已读 100%'
            : '已读 $pct%';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => _continueReading(book),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.shadowColor,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        book.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () => _showMenu(book),
                        child: const Icon(CupertinoIcons.ellipsis,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
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
                color: AppTheme.primaryText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              progressLabel,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
