/// 任务模型
class Task {
  final int id;
  final int userId;
  final int bookId;
  final String taskType;
  final String status;
  final int progress;
  final String? errorMessage;
  final String? celeryTaskId;
  final String createdAt;
  final String updatedAt;
  final String? completedAt;

  Task({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.taskType,
    required this.status,
    required this.progress,
    this.errorMessage,
    this.celeryTaskId,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json["id"] as int,
      userId: json["user_id"] as int,
      bookId: json["book_id"] as int,
      taskType: json["task_type"] as String? ?? "tts",
      status: json["status"] as String? ?? "pending",
      progress: json["progress"] as int? ?? 0,
      errorMessage: json["error_message"] as String?,
      celeryTaskId: json["celery_task_id"] as String?,
      createdAt: json["created_at"] as String? ?? "",
      updatedAt: json["updated_at"] as String? ?? "",
      completedAt: json["completed_at"] as String?,
    );
  }
}
