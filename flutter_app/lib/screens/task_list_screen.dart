import "dart:async";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../theme/app_theme.dart";
import "../widgets/common_widgets.dart";
import "../providers/task_provider.dart";
import "upload_screen.dart";

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});
  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        final tp = context.read<TaskProvider>();
        final hasActive = tp.tasks.any((t) => t.status == "processing" || t.status == "pending");
        if (hasActive) tp.loadTasks();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TaskProvider>();
    final tasks = tp.tasks;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          automaticallyImplyLeading: false,
          floating: true,
          backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
          surfaceTintColor: Colors.transparent,
          title: Text("任务", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.3)),
          actions: [
            IconButton(icon: Icon(Icons.refresh, size: 20, color: cs.onSurface.withValues(alpha: 0.4)), onPressed: () => tp.loadTasks()),
          ],
        ),
        if (tasks.isEmpty)
          SliverFillRemaining(
            child: EmptyState(
              icon: Icons.task_alt_rounded,
              title: "暂无任务",
              subtitle: "上传小说后将自动创建生成任务",
              actionLabel: "去上传",
              onAction: () => Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const UploadScreen())).then((r) {
                if (r == true) tp.loadTasks();
              }),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((ctx, i) => _TaskCard(task: tasks[i]),
              childCount: tasks.length),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ]),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final dynamic task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = AppTheme.statusColor(task.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: isDark ? AppTheme.cardDark : Colors.white, borderRadius: BorderRadius.circular(AppTheme.radiusLg), boxShadow: AppTheme.cardShadow(cs.onSurface, opacity: 0.03, blur: 8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text("书籍 #${task.bookId} · 任务 #${task.id}", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface))),
            StatusTag(status: task.status),
          ]),
          if (task.status == "processing") Padding(padding: const EdgeInsets.only(top: 12), child: ClipRRect(borderRadius: BorderRadius.circular(AppTheme.radiusFull), child: LinearProgressIndicator(value: (task.progress ?? 0) / 100, minHeight: 4, backgroundColor: statusColor.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(statusColor)))),
          if (task.status == "failed" && task.errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(task.errorMessage!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppTheme.danger))),
          Row(children: [
            Text(task.createdAt, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.3))),
            const Spacer(),
            // 操作按钮
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
              itemBuilder: (ctx) {
                final items = <PopupMenuItem<String>>[];
                if (task.status == "failed") items.add(const PopupMenuItem(value: "retry", child: Row(children: [Icon(Icons.refresh, size: 16), SizedBox(width: 8), Text("重试")])));
                items.add(const PopupMenuItem(value: "delete", child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text("删除", style: TextStyle(color: Colors.red))])));
                return items;
              },
              onSelected: (v) async {
                if (v == "retry") await context.read<TaskProvider>().retryTask(task.bookId);
                if (v == "delete") {
                  final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)), title: const Text("删除任务"), content: const Text("确定要删除此任务吗？"), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("取消")), FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.danger), onPressed: () => Navigator.pop(c, true), child: const Text("删除"))]));
                  if (confirm == true) await context.read<TaskProvider>().deleteTask(task.id);
                }
              },
            )
          ]),
        ])),
        if (task.status == "completed")
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pushNamed(context, "/book", arguments: task.bookId), icon: Icon(Icons.library_books, size: 16), label: Text("查看书籍"))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(onPressed: () => Navigator.pushNamed(context, "/player", arguments: task.bookId), icon: Icon(Icons.play_arrow_rounded, size: 16), label: Text("播放"))),
          ])),
      ]),
    );
  }
}
