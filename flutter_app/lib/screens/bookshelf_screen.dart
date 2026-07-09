import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../theme/app_theme.dart";
import "../widgets/common_widgets.dart";
import "../providers/book_provider.dart";
import "../models/book.dart";
import "upload_screen.dart";

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  final _searchCtrl = TextEditingController();
  SortMode _sortMode = SortMode.updated;
  String _filterStatus = "all";
  bool _showGrid = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await context.read<BookProvider>().loadBooks();
    if (mounted) setState(() => _loading = false);
  }

  List<Book> _getFiltered(List<Book> books) {
    var filtered = books;
    if (_searchCtrl.text.isNotEmpty) {
      final q = _searchCtrl.text.toLowerCase();
      filtered = filtered.where((b) => b.title.toLowerCase().contains(q) || (b.author ?? "").toLowerCase().contains(q)).toList();
    }
    if (_filterStatus != "all") {
      filtered = filtered.where((b) => b.status == _filterStatus).toList();
    }
    switch (_sortMode) {
      case SortMode.updated:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case SortMode.title:
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortMode.created:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final books = _getFiltered(context.watch<BookProvider>().books);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部标题
          SliverAppBar(
            automaticallyImplyLeading: false,
            floating: true,
            expandedHeight: 60,
            backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
            surfaceTintColor: Colors.transparent,
            title: Text("我的书架", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.3)),
            actions: [
              IconButton(
                icon: Icon(_showGrid ? Icons.view_list_rounded : Icons.grid_view_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
                onPressed: () => setState(() => _showGrid = !_showGrid),
              ),
              IconButton(
                icon: Icon(Icons.upload_outlined, color: cs.onSurface.withValues(alpha: 0.5)),
                onPressed: () => Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const UploadScreen())).then((r) {
                  if (r == true) _refresh();
                }),
              ),
            ],
          ),
          // 搜索框
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "搜索书名或作者...",
                  prefixIcon: Icon(Icons.search, color: cs.onSurface.withValues(alpha: 0.3)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(icon: Icon(Icons.close, color: cs.onSurface.withValues(alpha: 0.3), size: 18), onPressed: () { _searchCtrl.clear(); setState(() {}); })
                      : null,
                ),
              ),
            ),
          ),
          // 排序和筛选
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _SortChip(
                    label: _sortLabel,
                    icon: Icons.sort_rounded,
                    onTap: () => _showSortSheet(context),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: _filterStatusLabel,
                    icon: Icons.filter_list_rounded,
                    onTap: () => _showFilterSheet(context),
                    active: _filterStatus != "all",
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          // 书籍列表
          if (_loading)
            SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: cs.primary)))
          else if (books.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.library_books_outlined,
                title: "书架空空如也",
                subtitle: "上传小说开始生成你的有声书",
                actionLabel: "去上传",
                onAction: () => Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const UploadScreen())).then((r) {
                  if (r == true) _refresh();
                }),
              ),
            )
          else if (_showGrid)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.54,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _BookGridItem(book: books[i]),
                  childCount: books.length,
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _BookListItem(book: books[i]),
                childCount: books.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  String get _sortLabel {
    switch (_sortMode) {
      case SortMode.updated: return "最近更新";
      case SortMode.title: return "书名排序";
      case SortMode.created: return "最新创建";
    }
  }

  String get _filterStatusLabel {
    switch (_filterStatus) {
      case "all": return "全部";
      case "completed": return "已完成";
      case "processing": return "合成中";
      case "failed": return "失败";
      default: return "全部";
    }
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text("排序方式", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 16),
            for (final m in SortMode.values)
              ListTile(
                leading: Icon(m == _sortMode ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: AppTheme.primaryLight),
                title: Text(_sortModeLabel(m)),
                onTap: () { setState(() => _sortMode = m); Navigator.pop(ctx); },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _sortModeLabel(SortMode m) {
    switch (m) {
      case SortMode.updated: return "最近更新";
      case SortMode.title: return "书名排序";
      case SortMode.created: return "最新创建";
    }
  }

  void _showFilterSheet(BuildContext context) {
    final filters = [
      ("all", "全部"),
      ("completed", "已完成"),
      ("processing", "合成中"),
      ("failed", "失败"),
      ("pending", "等待中"),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text("筛选状态", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: filters.map((f) {
                final active = _filterStatus == f.$1;
                return FilterChip(
                  label: Text(f.$2),
                  selected: active,
                  onSelected: (_) { setState(() => _filterStatus = f.$1); Navigator.pop(ctx); },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

enum SortMode { updated, title, created }

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SortChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary)),
            Icon(Icons.arrow_drop_down, size: 16, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _FilterChip({required this.label, required this.icon, required this.onTap, required this.active});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? cs.primary.withValues(alpha: 0.08) : cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: active ? cs.primary.withValues(alpha: 0.2) : cs.onSurface.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.6))),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }
}

class _BookGridItem extends StatelessWidget {
  final Book book;
  const _BookGridItem({required this.book});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, "/book", arguments: book.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: "book_cover_${book.id}",
            child: BookCover(title: book.title, coverUrl: book.coverUrl, width: double.infinity, height: 160, radius: AppTheme.radiusMd),
          ),
          const SizedBox(height: 8),
          Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface, height: 1.3)),
          const SizedBox(height: 4),
          Row(
            children: [
              if (book.status == "completed")
                Icon(Icons.play_circle_fill, size: 12, color: AppTheme.success)
              else
                Icon(AppTheme.statusIcon(book.status), size: 12, color: AppTheme.statusColor(book.status)),
              const SizedBox(width: 3),
              Expanded(child: Text(AppTheme.statusLabel(book.status), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4)))),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookListItem extends StatelessWidget {
  final Book book;
  const _BookListItem({required this.book});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, "/book", arguments: book.id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow(cs.onSurface, opacity: 0.04, blur: 10),
        ),
        child: Row(
          children: [
            Hero(tag: "book_cover_${book.id}", child: BookCover(title: book.title, coverUrl: book.coverUrl, width: 60, height: 80, radius: AppTheme.radiusSm)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface, height: 1.3)),
                  if (book.author != null && book.author!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4))),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StatusTag(status: book.status),
                      const Spacer(),
                      if (book.status == "completed")
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, "/player", arguments: book.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppTheme.primaryLight.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.play_arrow_rounded, size: 16, color: AppTheme.primaryLight),
                              const SizedBox(width: 4),
                              Text("播放", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryLight)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
