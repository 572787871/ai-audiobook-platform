/// 书籍详情页 - 正式听书 App 风格
import "dart:async";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/book_provider.dart";
import "../models/book.dart";
import "../theme/app_theme.dart";

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: bp.isLoading && detail == null
          ? const Center(child: CircularProgressIndicator())
          : detail == null
              ? Center(child: Text(bp.error ?? "加载失败"))
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 280,
                      pinned: true,
                      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [AppTheme.primary.withOpacity(0.8), isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight],
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 160, height: 210,
                              margin: const EdgeInsets.only(top: 60),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.white.withOpacity(0.15),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))],
                              ),
                              child: Icon(Icons.book, size: 64, color: Colors.white.withOpacity(0.6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 标题和作者
                            Text(detail.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textPrimary)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (detail.author != null) ...[
                                  Icon(Icons.person, size: 16, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(detail.author!, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                  const SizedBox(width: 16),
                                ],
                                Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(detail.createdAt.substring(0, 10), style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 状态
                            _StatusBadge(status: detail.status),
                            const SizedBox(height: 16),
                            if (detail.audioDuration != null)
                              Row(
                                children: [
                                  const Icon(Icons.timer, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text("时长: ${detail.audioDuration!.toStringAsFixed(0)}秒", style: TextStyle(color: Colors.grey.shade600)),
                                ],
                              ),
                            const SizedBox(height: 20),
                            if (detail.description != null) ...[
                              Text(detail.description!, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : AppTheme.textSecondary, height: 1.6)),
                              const SizedBox(height: 20),
                            ],

                            // 章节
                            if (detail.chapters.isNotEmpty) ...[
                              const Divider(),
                              const SizedBox(height: 12),
                              Text("章节 (${detail.chapters.length})", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textPrimary)),
                              const SizedBox(height: 8),
                              ...detail.chapters.map((c) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Center(child: Text("${c.index + 1}", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13))),
                                ),
                                title: Text(c.title, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : AppTheme.textSecondary)),
                                trailing: Text("${c.start.toStringAsFixed(0)}s", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              )),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _buildBottomBar(detail),
    );
  }

  Widget _buildBottomBar(BookDetail? detail) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
        ),
        child: Row(
          children: [
            if (detail != null && detail.status == "completed") ...[
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text("开始播放"),
                  onPressed: () => Navigator.pushNamed(context, "/player", arguments: detail.id),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_stories, size: 18),
                label: const Text("边看边听"),
                onPressed: () => Navigator.pushNamed(context, "/player", arguments: detail.id),
              ),
            ] else ...[
              Expanded(
                child: FilledButton.icon(
                  icon: Icon(detail!.status == "pending" ? Icons.hourglass_empty : Icons.sync, size: 20),
                  label: Text(detail!.status == "pending" ? "等待合成" : "合成中"),
                  onPressed: null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {
      "pending": (Colors.orange, Icons.hourglass_empty, "等待合成"),
      "processing": (AppTheme.primary, Icons.autorenew, "合成中"),
      "completed": (Colors.green, Icons.check_circle, "已完成"),
      "failed": (Colors.red, Icons.error, "失败"),
    };
    final (color, icon, label) = map[status] ?? (Colors.grey, Icons.help, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
