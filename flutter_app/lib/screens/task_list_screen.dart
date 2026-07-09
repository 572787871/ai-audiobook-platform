import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/task_provider.dart";
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
                  itemBuilder: (ctx, i) => _TaskCard(task: tasks[i], cs: cs),
                ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final ColorScheme cs;
  const _TaskCard({required this.task, required this.cs});

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
            if (task.status == "failed")
              TextButton(onPressed: () async {
                await context.read<TaskProvider>().cancelTask(task.id);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已重试")));
              }, child: const Text("重试")),
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
