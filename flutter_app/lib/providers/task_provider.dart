/// Task Provider：任务状态管理
import "dart:async";
import "package:flutter/foundation.dart";
import "../services/api_service.dart";
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
      _tasks = await ApiService.listTasks(statusFilter: statusFilter);
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
    try {
      return await ApiService.getTask(id);
    } catch (e) {
      return null;
    }
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
      final task = await ApiService.cancelTask(id);
      final idx = _tasks.indexWhere((t) => t.id == id);
      if (idx >= 0) _tasks[idx] = task;
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
      await ApiService.deleteTask(id);
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
