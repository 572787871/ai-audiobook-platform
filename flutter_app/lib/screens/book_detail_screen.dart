/// 书籍详情页：状态面板 + 封面 + 操作按钮
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadDetail(widget.bookId);
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (mounted) {
        final bp = context.read<BookProvider>();
        final d = bp.currentDetail;
        if (d != null && (d.status == "pending" || d.status == "processing")) {
          await bp.refreshDetail();
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
    final bp = context.watch<BookProvider>();
    final detail = bp.currentDetail;
    return Scaffold(
      appBar: AppBar(title: const Text("书籍详情"), actions: [
        if (detail != null && detail.status == "completed")
          PopupMenuButton(itemBuilder: (_) => [
            const PopupMenuItem(value: "delete", child: Text("删除", style: TextStyle(color: Colors.red))),
            const PopupMenuItem(value: "regenerate", child: Text("重新生成")),
          ], onSelected: (v) async {
            if (v == "delete") {
              await bp.deleteBook(detail.id);
              if (mounted) Navigator.pop(context);
            } else if (v == "regenerate") {
              await bp.createTask(detail.id);
            }
          }),
      ]),
      body: bp.isLoading && detail == null
          ? const Center(child: CircularProgressIndicator())
          : detail == null
              ? Center(child: Text(bp.error ?? "加载失败"))
              : _DetailBody(detail: detail, bp: bp),
      bottomNavigationBar: detail == null ? null : _BottomBar(detail: detail),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final BookDetail detail;
  final BookProvider bp;
  const _DetailBody({required this.detail, required this.bp});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = detail.status == "completed";
    final isProcessing = detail.status == "processing";
    final isPending = detail.status == "pending";
    final isFailed = detail.status == "failed";

    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        // 封面区域
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [theme.colorScheme.primaryContainer, theme.colorScheme.surface],
            ),
          ),
          child: Column(children: [
            SizedBox(width: 180, height: 240, child: ClipRRect(borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Center(child: Icon(Icons.menu_book, size: 72, color: theme.colorScheme.primary.withOpacity(0.4))),
              ))),
            const SizedBox(height: 20),
            Text(detail.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            if (detail.author != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(detail.author!, style: TextStyle(fontSize: 15, color: Colors.grey.shade600))),
            const SizedBox(height: 8),
            _StatusBadge(status: detail.status),
          ]),
        ),
        // 生成进度
        if (isProcessing || isPending) _BuildProgress(detail: detail),
        // 信息区域
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (detail.description != null && detail.description!.isNotEmpty) ...[
              const Text("简介", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(detail.description!, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6)),
              const SizedBox(height: 20),
            ],
            _InfoRow(label: "文件格式", value: "TXT"),
            _InfoRow(label: "上传时间", value: detail.createdAt.length > 10 ? detail.createdAt.substring(0, 10) : detail.createdAt),
            _InfoRow(label: "生成状态", value: isCompleted ? "已完成" : isProcessing ? "合成中" : isPending ? "等待中" : isFailed ? "失败" : detail.status),
            if (detail.audioDuration != null) _InfoRow(label: "音频时长", value: "${detail.audioDuration!.toStringAsFixed(0)} 秒"),
            // 章节列表
            if (detail.chapters.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(children: [Text("章节 (${detail.chapters.length})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(), TextButton.icon(icon: const Icon(Icons.list, size: 16), label: const Text("全部"))]),
              ...detail.chapters.map((c) => ListTile(dense: true, leading: Text("#${c.index + 1}"),
                title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text("${c.start.toStringAsFixed(1)}s - ${c.end.toStringAsFixed(1)}s"))),
            ],
            if (detail.transcript.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [Text("字幕 (${detail.transcript.length} 句)", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(), TextButton.icon(icon: const Icon(Icons.visibility, size: 16), label: const Text("预览"))]),
            ],
          ]),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _BuildProgress extends StatelessWidget {
  final BookDetail detail;
  const _BuildProgress({required this.detail});

  @override
  Widget build(BuildContext context) {
    final steps = ["解析中", "分章中", "合成中", "生成字幕中"];
    final currentStep = detail.chapters.isEmpty ? 0 : (detail.audioDuration != null ? 3 : 1);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("生成进度", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(e.key <= currentStep ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20, color: e.key <= currentStep ? Colors.green : Colors.grey),
            const SizedBox(width: 8),
            Text(e.value, style: TextStyle(color: e.key <= currentStep ? null : Colors.grey)),
          ]),
        )),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final map = {"pending": (Colors.orange, "等待中"), "processing": (Colors.blue, "合成中"),
      "completed": (Colors.green, "已完成"), "failed": (Colors.red, "失败")};
    final data = map[status] ?? (Colors.grey, status);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: data.$1.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(data.$2, style: TextStyle(color: data.$1, fontSize: 13, fontWeight: FontWeight.w600)));
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)), const Spacer(),
        Text(value, style: const TextStyle(fontSize: 14))]));
  }
}

class _BottomBar extends StatelessWidget {
  final BookDetail detail;
  const _BottomBar({required this.detail});

  @override
  Widget build(BuildContext context) {
    final isCompleted = detail.status == "completed";
    final isProcessing = detail.status == "processing";
    final isPending = detail.status == "pending";
    final isFailed = detail.status == "failed";

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: isCompleted
            ? Row(children: [
                Expanded(child: FilledButton.icon(icon: const Icon(Icons.play_arrow, size: 20), label: const Text("开始播放"),
                  onPressed: () => Navigator.pushNamed(context, "/player", arguments: detail.id))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.menu_book, size: 18), label: const Text("边看边听"),
                  onPressed: () => Navigator.pushNamed(context, "/player", arguments: {"bookId": detail.id, "readAlong": true}))),
              ])
            : isFailed
                ? SizedBox(width: double.infinity, child: FilledButton.icon(icon: const Icon(Icons.refresh), label: const Text("重新生成"),
                    onPressed: () => context.read<BookProvider>().createTask(detail.id)))
                : SizedBox(width: double.infinity, child: FilledButton.icon(
                    icon: Icon(isPending ? Icons.hourglass_empty : Icons.sync, size: 20),
                    label: Text(isPending ? "等待合成" : "合成中..."),
                    onPressed: null)),
      ),
    );
  }
}
