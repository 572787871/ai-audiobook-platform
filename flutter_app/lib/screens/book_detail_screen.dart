/// 有声书详情页
import "dart:async";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:cached_network_image/cached_network_image.dart";
import "../providers/book_provider.dart";
import "../models/book.dart";

class BookDetailScreen extends StatefulWidget {
  final int bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadDetail(widget.bookId);
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (mounted && context.read<BookProvider>().currentDetail != null) {
        await context.read<BookProvider>().refreshDetail();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BookProvider>();
    final detail = bp.currentDetail;
    return Scaffold(
      appBar: AppBar(title: const Text("详情"), actions: [
        IconButton(icon: const Icon(Icons.delete), onPressed: () async {
          if (detail == null) return;
          final ok = await bp.deleteBook(detail.id);
          if (ok && context.mounted) Navigator.pop(context);
        }),
      ]),
      body: bp.isLoading && detail == null
          ? const Center(child: CircularProgressIndicator())
          : detail == null
              ? Center(child: Text(bp.error ?? "加载失败"))
              : _DetailBody(detail: detail),
      bottomNavigationBar: detail == null ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: Text(detail.status == "completed" ? "播放" : "等待合成"),
                  onPressed: detail.status == "completed"
                      ? () => Navigator.pushNamed(context, "/player", arguments: detail.id)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              if (detail.status == "completed")
                IconButton(icon: const Icon(Icons.download), onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("音频下载已开始")));
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final BookDetail detail;
  const _DetailBody({required this.detail});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: SizedBox(width: 160, height: 200, child: ClipRRect(borderRadius: BorderRadius.circular(12),
          child: detail.coverUrl != null ? CachedNetworkImage(imageUrl: detail.coverUrl!, fit: BoxFit.cover)
              : Container(color: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.book, size: 64, color: Theme.of(context).colorScheme.primary))))),
        const SizedBox(height: 16),
        Center(child: Text(detail.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        if (detail.author != null) Center(child: Text(detail.author!, style: TextStyle(fontSize: 16, color: Colors.grey.shade600))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_StatusChip(status: detail.status)]),
        const SizedBox(height: 20),
        if (detail.description != null) ...[
          const Text("简介", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          Text(detail.description!),SizedBox(height: 16),
        ],
        if (detail.audioDuration != null)
          Text("时长：\${detail.audioDuration!.toStringAsFixed(0)} 秒", style: TextStyle(color: Colors.grey.shade700)),
        if (detail.chapters.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text("章节", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          ...detail.chapters.map((c) => ListTile(dense: true, leading: Text("#\${c.index + 1}"), title: Text(c.title), subtitle: Text("\${c.start.toStringAsFixed(1)}s - \${c.end.toStringAsFixed(1)}s"))),
        ],
        if (detail.transcript.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text("字幕", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          ...detail.transcript.take(20).map((t) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 60, child: Text("\${t.start.toStringAsFixed(1)}s", style: const TextStyle(fontSize: 12, color: Colors.grey))),
            const SizedBox(width: 8),
            Expanded(child: Text(t.text)),
          ]))),
          if (detail.transcript.length > 20)
            Text("... 还有 \${detail.transcript.length - 20} 条", style: const TextStyle(color: Colors.grey)),
        ],
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {
      "pending": (Colors.orange, Icons.hourglass_empty, "等待中"),
      "processing": (Colors.blue, Icons.autorenew, "合成中"),
      "completed": (Colors.green, Icons.check_circle, "已完成"),
      "failed": (Colors.red, Icons.error, "失败"),
    };
    final (color, icon, label) = map[status] ?? (Colors.grey, Icons.help, status);
    return Chip(avatar: Icon(icon, color: color, size: 18), label: Text(label), backgroundColor: color.withOpacity(0.1));
  }
}
