/// Task Provider：任务状态管理
import "dart:async";
import "package:flutter/foundation.dart";
import "../models/task.dart";

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;
  Timer? _pollTimer;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 加载任务列表
  Future<void> loadTasks({String? statusFilter}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _tasks = [];
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 轮询单个任务状态
  Future<Task?> pollTask(int id) async {
    return null;
  }

  Future<Task?> createTask(int bookId, {Map<String, dynamic>? params}) async {
    try {
      _error = "云端生成已关闭，请使用本地生成";
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> retryTask(int bookId) async {
    _error = "云端重试已关闭，请在书籍详情页使用本地重新生成";
    notifyListeners();
    return false;
  }

  /// 启动自动轮询（用于任务列表页）
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await loadTasks();
    });
  }

  /// 停止轮询
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// 取消任务
  Future<bool> cancelTask(int id) async {
    try {
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask(int id) async {
    try {
      _tasks.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
