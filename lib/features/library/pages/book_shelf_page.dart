import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../../../theme/app_theme.dart';
import '../models/book.dart';
import '../models/book_file_type.dart';
import '../models/library_change_result.dart';
import '../services/book_repository.dart';
import '../widgets/book_cover_widget.dart';
import 'book_detail_page.dart';
import '../../reader/pages/reader_page.dart';

/// 书架页：独立页面，分类栏 + 两列实体书封面书架。
class BookShelfPage extends StatefulWidget {
  final BookRepositoryBase? repository;
  final Future<String> Function(Book book)? contentLoader;

  const BookShelfPage({super.key, this.repository, this.contentLoader});

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
    // 保留旧列表：不先清空，避免返回时书架闪空
    if (mounted) setState(() => _loading = true);
    final books = await _repo.loadAll();
    books.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (!mounted) return;
    setState(() {
      _books
        ..clear()
        ..addAll(books);
      _loading = false;
    });
  }

  /// 原地替换某本书（返回进度/重命名后轻量刷新，不闪空、不全量 reload）
  void _replaceBook(Book updated) {
    final idx = _books.indexWhere((b) => b.id == updated.id);
    if (idx >= 0) {
      setState(() => _books[idx] = updated);
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
      await _repo.save(book.copyWith(title: result, updatedAt: DateTime.now()));
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
      if (!mounted) return;
      setState(() => _books.removeWhere((b) => b.id == book.id));
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
      if (mounted) {
        setState(() {
          _books.removeWhere((b) => ids.contains(b.id));
          _editing = false;
        });
      }
      _load();
    }
  }

  /// 进入详情（长按下/菜单选「书籍详情」才走这里）。
  Future<void> _openDetail(Book book) async {
    final result = await Navigator.of(context).push<LibraryChangeResult?>(
      CupertinoPageRoute(
        builder: (_) => BookDetailPage(book: book, repository: _repo),
      ),
    );
    if (!mounted) return;
    if (result == LibraryChangeResult.deleted) {
      setState(() => _books.removeWhere((b) => b.id == book.id));
    } else {
      // 非删除：后台平滑刷新（_load 已保留旧列表，不闪空）
      await _load();
    }
  }

  /// 点击封面直接进阅读器，返回书架（非详情）。
  Future<void> _openReader(Book book) async {
    if (book.fileType != BookFileType.txt) {
      _toast('该书暂未解析，无法阅读');
      return;
    }
    final updated = await Navigator.of(context).push<Book?>(
      CupertinoPageRoute(
        builder: (_) => ReaderPage(
              book: book,
              repository: _repo,
              contentLoader: widget.contentLoader,
            ),
      ),
    );
    if (!mounted) return;
    // 单一刷新策略：原地替换返回的最近阅读进度，不闪空
    if (updated != null) {
      _replaceBook(updated);
    } else {
      _replaceBook(book);
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
              _openReader(book);
            },
            child: const Text('继续阅读'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _toast('AI 听书将在后续阶段接入 Kokoro');
            },
            child: const Text('开始听书'),
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
          onPressed: () {
            // 返回首页，并通知其刷新数量（删除/新增后同步）
            Navigator.of(context).pop(true);
          },
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
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: _books.isNotEmpty
                  ? _buildBody() // 有书时保留列表，后台刷新不闪空
                  : (_loading
                      ? const Center(child: CupertinoActivityIndicator())
                      : _buildBody()), // 空状态仅当 !loading && 无书
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '共 ${_books.length} 本书',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    const tabs = ['全部', '阅读中', '已完成'];
    final counts = [
      _books.length,
      _books.where((b) => b.readingProgress > 0 && b.readingProgress < 1).length,
      _books.where((b) => b.readingProgress >= 1).length,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _filter = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _filter == i
                      ? CupertinoColors.activeBlue
                      : AppTheme.iconBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabs[i],
                      style: TextStyle(
                        fontSize: 14,
                        color: _filter == i
                            ? CupertinoColors.white
                            : AppTheme.primaryText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${counts[i]}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _filter == i
                            ? CupertinoColors.white
                            : AppTheme.secondaryText,
                      ),
                    ),
                  ],
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 3 / 4.6,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _bookCard(items[i]),
    );
  }

  Widget _bookCard(Book book) {
    final selected = _selected.contains(book.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
          _openReader(book);
        }
      },
      onLongPress: _editing ? null : () => _showMenu(book),
      child: Container(
        color: AppTheme.background,
        child: Stack(
        children: [
          Positioned.fill(
            child: BookCoverWidget(
              key: Key('book_${book.id}'),
              book: book,
            ),
          ),
          // 右上角 ••• 菜单
          if (!_editing)
            Positioned(
              top: 4,
              right: 4,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(CupertinoIcons.ellipsis,
                      size: 18, color: CupertinoColors.white),
                ),
                onPressed: () => _showMenu(book),
              ),
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
                      : Colors.white.withValues(alpha: 0.85),
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
      ),
    );
  }
}
