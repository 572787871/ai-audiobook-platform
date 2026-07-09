import "dart:async";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
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
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<BookProvider>().loadDetail(widget.bookId));
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (mounted && context.read<BookProvider>().currentDetail != null) {
        final s = context.read<BookProvider>().currentDetail!.status;
        if (s == "processing" || s == "pending") {
          await context.read<BookProvider>().refreshDetail();
        }
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
    final cs = Theme.of(context).colorScheme;
    final bp = context.watch<BookProvider>();
    final detail = bp.currentDetail;

    return Scaffold(
      appBar: AppBar(title: const Text("书籍详情"), actions: [
        if (detail != null && detail.status == "completed")
          PopupMenuButton<String>(onSelected: (v) async {
            if (v == "delete") { await bp.deleteBook(detail.id); if (context.mounted) Navigator.pop(context); }
            if (v == "regenerate") { await bp.createTask(detail.id); }
          }, itemBuilder: (_) => const [
            PopupMenuItem(value: "regenerate", child: ListTile(leading: Icon(Icons.refresh), title: Text("重新生成"), dense: true)),
            PopupMenuItem(value: "delete", child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text("删除", style: TextStyle(color: Colors.red)), dense: true)),
          ]),
      ]),
      body: bp.isLoading && detail == null
          ? const Center(child: CircularProgressIndicator())
          : detail == null
              ? Center(child: Text(bp.error ?? "加载失败"))
              : _Body(detail: detail, cs: cs),
      bottomNavigationBar: detail == null ? null : _BottomBar(detail: detail, cs: cs),
    );
  }
}

class _Body extends StatelessWidget {
  final BookDetail detail;
  final ColorScheme cs;
  const _Body({required this.detail, required this.cs});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      // 封面区
      Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [cs.primaryContainer, cs.primaryContainer.withValues(alpha: 0.3)]),
        ),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.auto_stories, size: 64, color: cs.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(detail.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          if (detail.author != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(detail.author!, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)))),
        ])),
      ),
      const SizedBox(height: 16),
      // 状态卡片
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          _statusIcon(detail.status),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_statusLabel(detail.status), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_statusDesc(detail.status), style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13)),
          ])),
          if (detail.status == "processing" || detail.status == "pending") const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
      ),
      const SizedBox(height: 12),
      // 信息卡片
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          _InfoRow(label: "文件名", value: "源文件.txt"),
          _InfoRow(label: "格式", value: "TXT"),
          _InfoRow(label: "上传时间", value: detail.createdAt.substring(0, 10)),
          _InfoRow(label: "状态", value: _statusLabel(detail.status)),
          if (detail.audioDuration != null) _InfoRow(label: "时长", value: "${detail.audioDuration!.toStringAsFixed(0)} 秒"),
          if (detail.chapters.isNotEmpty) _InfoRow(label: "章节", value: "${detail.chapters.length} 章"),
        ]),
      ),
      if (detail.description != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("简介", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(detail.description!, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
          ]),
        ),
      ],
      if (detail.chapters.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text("章节列表", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...detail.chapters.map((c) => ListTile(dense: true, leading: Text("#${c.index + 1}"), title: Text(c.title), subtitle: Text("${c.start.toStringAsFixed(1)}s - ${c.end.toStringAsFixed(1)}s"))),
      ],
      const SizedBox(height: 80),
    ]);
  }

  Widget _statusIcon(String s) {
    switch (s) {
      case "completed": return const Icon(Icons.check_circle, color: Colors.green, size: 36);
      case "processing": return const Icon(Icons.sync, color: Colors.orange, size: 36);
      case "failed": return const Icon(Icons.error, color: Colors.red, size: 36);
      default: return const Icon(Icons.hourglass_empty, color: Colors.grey, size: 36);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case "completed": return "已完成";
      case "processing": return "合成中";
      case "failed": return "生成失败";
      default: return "等待中";
    }
  }

  String _statusDesc(String s) {
    switch (s) {
      case "completed": return "音频已生成，可以播放了";
      case "processing": return "正在处理，请稍候...";
      case "failed": return "生成过程中出现错误";
      default: return "任务已提交，等待处理";
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
    ]));
  }
}

class _BottomBar extends StatelessWidget {
  final BookDetail detail;
  final ColorScheme cs;
  const _BottomBar({required this.detail, required this.cs});

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        if (detail.status == "completed") ...[
          Expanded(child: _ActionButton(
            icon: Icons.play_arrow, label: "开始播放",
            onTap: () => Navigator.pushNamed(context, "/player", arguments: detail.id),
          )),
          const SizedBox(width: 12),
          Expanded(child: _ActionButton(
            icon: Icons.menu_book, label: "边看边听",
            onTap: () => Navigator.pushNamed(context, "/read", arguments: detail.id),
          )),
          const SizedBox(width: 12),
          IconButton(
            style: IconButton.styleFrom(backgroundColor: cs.surfaceContainerHighest, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.download), onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("下载已开始")));
            },
          ),
        ] else if (detail.status == "processing" || detail.status == "pending") ...[
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text(detail.status == "pending" ? "等待合成" : "合成中", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
            ]),
          )),
        ] else ...[
          Expanded(child: _ActionButton(
            icon: Icons.refresh, label: "重新生成",
            onTap: () async {
              await context.read<BookProvider>().createTask(detail.id);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已重新提交任务")));
            },
          )),
        ],
      ]),
    ));
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: Icon(icon), label: Text(label, style: const TextStyle(fontSize: 14)),
      onPressed: onTap,
    );
  }
}
