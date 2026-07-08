/// 任务列表页
import "dart:async";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/task_provider.dart";

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
    final tp = context.watch<TaskProvider>();
    final tasks = tp.tasks;
    return Scaffold(
      appBar: AppBar(title: const Text("任务列表")),
      body: tp.isLoading && tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.inbox, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("暂无任务"),
                ]))
              : ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) {
                    final t = tasks[i];
                    final color = {"pending": Colors.orange, "processing": Colors.blue, "completed": Colors.green, "failed": Colors.red}[t.status] ?? Colors.grey;
                    final label = {"pending": "等待中", "processing": "处理中", "completed": "已完成", "failed": "失败"}[t.status] ?? t.status;
                    return ListTile(
                      leading: CircularProgressIndicator(value: null, strokeWidth: 3, color: color),
                      title: Text("#" + t.id.toString() + " - " + t.taskType),
                      subtitle: Text(label + "  " + t.progress.toString() + "%"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(context, "/task", arguments: t.id),
                    );
                  },
                ),
    );
  }
}
