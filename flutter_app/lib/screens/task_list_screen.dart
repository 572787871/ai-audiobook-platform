import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/task_provider.dart";
import "../services/api_service.dart";
import "../models/task.dart";

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
      context.read<TaskProvider>().startPolling();
    });
  }

  @override
  void dispose() {
    context.read<TaskProvider>().stopPolling();
    super.dispose();
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("删除任务"),
        content: Text("确定删除任务 #${task.id}？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("删除")),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.cancelTask(task.id);
        await context.read<TaskProvider>().loadTasks();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("删除失败: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tp = context.watch<TaskProvider>();
    final tasks = tp.tasks;

    return Scaffold(
      appBar: AppBar(title: const Text("生成任务", style: TextStyle(fontWeight: FontWeight.bold))),
      body: tp.isLoading && tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("暂无任务", style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text("上传小说后会自动创建生成任务", style: TextStyle(color: Colors.grey.shade400)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) => _TaskCard(
                    task: tasks[i],
                    cs: cs,
                    onDelete: () => _deleteTask(tasks[i]),
                  ),
                ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final ColorScheme cs;
  final VoidCallback onDelete;
  const _TaskCard({required this.task, required this.cs, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(task.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(statusInfo.icon, color: statusInfo.color, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(statusInfo.label, style: TextStyle(fontWeight: FontWeight.bold, color: statusInfo.color)),
              Text("有声书 #${task.bookId}", style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
            ])),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == "delete") onDelete();
                if (v == "retry" && task.status == "failed") {
                  try {
                    await ApiService.cancelTask(task.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已重试")));
                      context.read<TaskProvider>().loadTasks();
                    }
                  } catch (_) {}
                }
              },
              itemBuilder: (_) => [
                if (task.status == "failed")
                  const PopupMenuItem(value: "retry", child: ListTile(leading: Icon(Icons.refresh), title: Text("重试"), dense: true)),
                const PopupMenuItem(value: "delete", child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text("删除", style: TextStyle(color: Colors.red)), dense: true)),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          if (task.status != "completed" && task.status != "failed")
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
              value: task.progress / 100.0, minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(statusInfo.color),
            )),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("进度: ${task.progress}%", style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
            Text(task.createdAt.substring(0, 16), style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4))),
          ]),
          if (task.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(task.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))),
              ])),
          ],
        ]),
      ),
    );
  }

  _StatusInfo _statusInfo(String s) {
    switch (s) {
      case "pending": return _StatusInfo(Icons.hourglass_empty, Colors.grey, "等待中");
      case "processing": return _StatusInfo(Icons.sync, Colors.blue, "合成中");
      case "completed": return _StatusInfo(Icons.check_circle, Colors.green, "已完成");
      case "failed": return _StatusInfo(Icons.error, Colors.red, "生成失败");
      default: return _StatusInfo(Icons.help, Colors.grey, s);
    }
  }
}

class _StatusInfo {
  final IconData icon;
  final Color color;
  final String label;
  _StatusInfo(this.icon, this.color, this.label);
}
