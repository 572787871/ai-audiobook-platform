import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/book_provider.dart";
import "../models/book.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final books = context.watch<BookProvider>().books;
    final recent = books.take(6).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text("AI有声书", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
            actions: [
              IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.pushNamed(context, "/settings")),
            ],
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "搜索有声书...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          )),
          // Pro 会员入口
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.workspace_premium, color: Colors.white, size: 32),
                title: const Text("升级 Pro 会员", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("无限生成 优先合成 无损下载", style: TextStyle(color: Colors.white70, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                onTap: () => Navigator.pushNamed(context, "/membership"),
              ),
            ),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          // 最近生成
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("最近生成", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
              TextButton(onPressed: () {}, child: const Text("查看全部")),
            ]),
          )),
          SliverToBoxAdapter(child: SizedBox(
            height: 200,
            child: recent.isEmpty
                ? Center(child: Column(children: [
                    const SizedBox(height: 40),
                    Icon(Icons.library_books_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text("还没有有声书", style: TextStyle(color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Text("点击下方上传创建", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ]))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: recent.length,
                    itemBuilder: (ctx, i) => _BookCard(book: recent[i]),
                  ),
          )),
          // 上传入口
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              icon: const Icon(Icons.add_circle_outline, size: 28),
              label: const Text("上传小说生成有声书", style: TextStyle(fontSize: 16)),
              onPressed: () => Navigator.pushNamed(context, "/upload"),
            ),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, "/book", arguments: book.id),
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cs.primaryContainer.withValues(alpha: 0.3),
            ),
            child: Center(child: Icon(Icons.auto_stories, size: 48, color: cs.primary.withValues(alpha: 0.5))),
          ),
          const SizedBox(height: 8),
          Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _statusColor(book.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(_statusLabel(book.status), style: TextStyle(fontSize: 10, color: _statusColor(book.status))),
            ),
          ]),
        ]),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case "completed": return Colors.green;
      case "processing": return Colors.orange;
      case "failed": return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case "completed": return "已完成";
      case "processing": return "合成中";
      case "failed": return "失败";
      default: return "等待中";
    }
  }
}
