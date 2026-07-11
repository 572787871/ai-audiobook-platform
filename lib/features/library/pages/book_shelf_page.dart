import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../../../theme/app_theme.dart';
import '../models/book.dart';
import '../models/book_file_type.dart';
import '../services/book_repository.dart';
import '../services/book_cover_service.dart';
import 'book_detail_page.dart';
import '../../reader/pages/reader_page.dart';

/// 书架页：独立页面，分类栏 + 网格封面书架。
class BookShelfPage extends StatefulWidget {
  final BookRepositoryBase? repository;

  const BookShelfPage({super.key, this.repository});

  @override
  State<BookShelfPage> createState() => _BookShelfPageState();
}

class _BookShelfPageState extends State<BookShelfPage> {
  final List<Book> _books = [];
  bool _loading = true;
  int _filter = 0; // 0 全部 1 阅读中 2 已完成
  bool _editing = false;
  final Set<String> _selected = {};

  BookRepositoryBase get _repo => widget.repository ?? BookRepository.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final books = await _repo.loadAll();
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

  List<Book> get _filtered {
    switch (_filter) {
      case 1:
        return _books
            .where((b) => b.readingProgress > 0 && b.readingProgress < 1)
            .toList();
      case 2:
        return _books.where((b) => b.readingProgress >= 1).toList();
      default:
        return _books;
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
      await _repo.save(updated);
      _load();
    }
  }

  Future<void> _delete(Book book) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除《${book.title}》？'),
        content: const Text('删除后不可恢复。'),
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
      await _repo.delete(book.id);
      _load();
    }
  }

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除 ${ids.length} 本书？'),
        content: const Text('删除后不可恢复。'),
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
      for (final id in ids) {
        await _repo.delete(id);
      }
      _selected.clear();
      setState(() => _editing = false);
      _load();
    }
  }

  void _openDetail(Book book) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BookDetailPage(book: book, repository: _repo),
      ),
    );
  }

  Future<void> _continueReading(Book book) async {
    if (book.fileType != BookFileType.txt) {
      _toast('该书暂未解析，无法阅读');
      return;
    }
    final result = await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ReaderPage(book: book, repository: _repo),
      ),
    );
    // 返回后刷新进度
    await _load();
    if (result != null && mounted) {
      // 占位：ReaderPage 已通过 repository 保存进度
    }
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
      navigationBar: CupertinoNavigationBar(
        middle: const Text('书库'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('返回'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: _editing
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text('取消'),
                onPressed: () => setState(() {
                  _editing = false;
                  _selected.clear();
                }),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    child: const Icon(CupertinoIcons.search, size: 22),
                    onPressed: () => _toast('搜索将在后续版本加入'),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    child: const Text('编辑'),
                    onPressed: () => setState(() => _editing = true),
                  ),
                ],
              ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : Column(
                children: [
                  _buildFilterBar(),
                  Expanded(child: _buildBody()),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterBar() {
    const tabs = ['全部', '阅读中', '已完成'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _filter = i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _filter == i
                      ? CupertinoColors.activeBlue
                      : AppTheme.iconBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    fontSize: 14,
                    color: _filter == i
                        ? CupertinoColors.white
                        : AppTheme.primaryText,
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          if (_editing)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _selected.isEmpty ? null : _deleteSelected,
              child: const Text('删除'),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_books.isEmpty) {
      return const Center(
        child: Text('书架空空如也，去首页导入吧',
            style: TextStyle(color: AppTheme.secondaryText)),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return const Center(
        child: Text('该分类下暂无书籍',
            style: TextStyle(color: AppTheme.secondaryText)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 3 / 4.6,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _bookCard(items[i]),
    );
  }

  Widget _bookCard(Book book) {
    final colors = BookCoverService.colorsFor(book);
    final pct = (book.readingProgress * 100).round();
    final progressLabel = book.readingProgress <= 0
        ? '未开始'
        : pct >= 100
            ? '已完成'
            : '已读 $pct%';
    final selected = _selected.contains(book.id);
    return GestureDetector(
      key: Key('book_${book.id}'),
      onTap: () {
        if (_editing) {
          setState(() {
            if (selected) {
              _selected.remove(book.id);
            } else {
              _selected.add(book.id);
            }
          });
        } else {
          _openDetail(book);
        }
      },
      onLongPress: () {
        if (!_editing) _showMenu(book);
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
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
                  // 书脊效果
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: Colors.black.withValues(alpha:0.18),
                        width: 4,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      book.title,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
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
          if (_editing)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? CupertinoColors.activeBlue
                      : Colors.white.withValues(alpha:0.85),
                  border: Border.all(
                    color: selected
                        ? CupertinoColors.activeBlue
                        : AppTheme.secondaryText,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(CupertinoIcons.check_mark,
                        size: 14, color: CupertinoColors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
