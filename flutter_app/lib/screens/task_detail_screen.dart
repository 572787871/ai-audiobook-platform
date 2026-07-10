import "package:flutter/material.dart";

class TaskDetailScreen extends StatelessWidget {
  final int taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("本地生成")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_iphone_rounded,
                  size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text("云端任务已关闭",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                "现在所有书籍导入、文本解析、语音生成和音频缓存都在本机完成。请从书籍详情页进入“本地生成 / 生成设置”。",
                textAlign: TextAlign.center,
                style: TextStyle(
                    height: 1.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        ..withValues(alpha: HOLDER__0.65)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("返回")),
            ],
          ),
        ),
      ),
    );
  }
}
