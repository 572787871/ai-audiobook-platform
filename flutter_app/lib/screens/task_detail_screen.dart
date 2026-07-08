/// 任务详情页：实时显示任务进度
import "dart:async";
import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../models/task.dart";

class TaskDetailScreen extends StatefulWidget {
  final int taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Task? _task;
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final t = await ApiService.getTask(widget.taskId);
      setState(() { _task = t; _loading = false; });
      if (t.status == "completed" || t.status == "failed") _timer?.cancel();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("任务详情"), actions: [
        if (_task != null && (_task!.status == "pending" || _task!.status == "processing"))
          IconButton(icon: const Icon(Icons.cancel), onPressed: () async {
            await ApiService.cancelTask(_task!.id);
            _load();
          }),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _task == null
              ? Center(child: Text(_error ?? "加载失败"))
              : _body(),
    );
  }

  Widget _body() {
    final t = _task!;
    final color = {"pending": Colors.orange, "processing": Colors.blue, "completed": Colors.green, "failed": Colors.red}[t.status] ?? Colors.grey;
    final label = {"pending": "等待中", "processing": "处理中", "completed": "已完成", "failed": "失败"}[t.status] ?? t.status;
    return ListView(padding: const EdgeInsets.all(24), children: [
      Center(child: Text(label, style: TextStyle(fontSize: 24, color: color, fontWeight: FontWeight.bold))),
      const SizedBox(height: 24),
      Text("任务 ID：#" + t.id.toString()),
      Text("有声书 ID：" + t.bookId.toString()),
      Text("类型：" + t.taskType),
      SizedBox(height: 16),
      LinearProgressIndicator(value: t.progress / 100.0, minHeight: 8, backgroundColor: Colors.grey.shade300, valueColor: AlwaysStoppedAnimation(color)),
      const SizedBox(height: 8),
      Text("进度：" + t.progress.toString() + "%"),
      if (t.errorMessage != null) ...[SizedBox(height: 16), Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text(t.errorMessage!, style: TextStyle(color: Colors.red)))],
      SizedBox(height: 16),
      Text("创建：" + t.createdAt),
      Text("更新：" + t.updatedAt),
      if (t.completedAt != null) Text("完成：" + t.completedAt!),
      if (t.status == "completed")
        Padding(padding: EdgeInsets.only(top: 24), child: FilledButton.icon(
          icon: const Icon(Icons.play_arrow), label: const Text("去播放"),
          onPressed: () => Navigator.pushReplacementNamed(context, "/player", arguments: t.bookId),
        )),
    ]);
  }
}
