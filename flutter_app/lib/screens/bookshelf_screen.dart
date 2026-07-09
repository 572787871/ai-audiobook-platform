import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/book_provider.dart";
import "../models/book.dart";
import "upload_screen.dart";

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  bool _grid = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<BookProvider>().loadBooks());
  }

  @override
  Widget build(BuildContext context) {
    final books = context.watch<BookProvider>().books;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false,
        title: const Text("我的书架", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Icon(_grid ? Icons.list : Icons.grid_view), onPressed: () => setState(() => _grid = !_grid)),
          IconButton(icon: const Icon(Icons.upload_outlined), onPressed: () => Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const UploadScreen())).then((result) { if (result == true) context.read<BookProvider>().loadBooks(); })),
        ],
      ),
      body: books.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.library_books_outlined, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text("书架空空", style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              Text("去首页上传小说生成有声书", style: TextStyle(color: Colors.grey.shade400)),
            ]))
          : _grid
              ? GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.7, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: books.length,
                  itemBuilder: (ctx, i) => _BookGridItem(book: books[i]),
                )
              : ListView.builder(
                  itemCount: books.length,
                  itemBuilder: (ctx, i) => _BookListItem(book: books[i]),
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
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 140, width: double.infinity,
            decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.3)),
            child: Center(child: Icon(Icons.auto_stories, size: 48, color: cs.primary.withValues(alpha: 0.4))),
          ),
          Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              Text(_progressLabel(book.status), style: TextStyle(fontSize: 11, color: _statusColor(book.status))),
              const Spacer(),
              if (book.status == "completed")
                const Icon(Icons.check_circle, size: 14, color: Colors.green),
            ]),
          ])),
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

  String _progressLabel(String s) {
    switch (s) {
      case "completed": return "已完成";
      case "processing": return "合成中";
      case "failed": return "失败";
      default: return "等待中";
    }
  }
}

class _BookListItem extends StatelessWidget {
  final Book book;
  const _BookListItem({required this.book});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 48, height: 64,
        decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.auto_stories),
      ),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_statusLabel(book.status), style: TextStyle(color: _statusColor(book.status))),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (book.status == "completed") ...[
          IconButton(icon: const Icon(Icons.play_circle, color: Colors.green), onPressed: () => Navigator.pushNamed(context, "/player", arguments: book.id)),
          IconButton(icon: const Icon(Icons.menu_book), onPressed: () => Navigator.pushNamed(context, "/read", arguments: book.id)),
        ],
      ]),
      onTap: () => Navigator.pushNamed(context, "/book", arguments: book.id),
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
