/// Book Provider：有声书状态管理
import "package:flutter/foundation.dart";
import "dart:io";
import "../services/api_service.dart";
import "../models/user.dart";
import "../models/book.dart";
import "../models/task.dart";

class BookProvider extends ChangeNotifier {
  List<Book> _books = [];
  bool _isLoading = false;
  String? _error;
  BookDetail? _currentDetail;

  List<Book> get books => _books;
  bool get isLoading => _isLoading;
  String? get error => _error;
  BookDetail? get currentDetail => _currentDetail;

  /// 获取有声书列表
  Future<void> loadBooks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _books = await ApiService.listBooks();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 上传有声书
  Future<Book?> uploadBook(File file, String title, {String? author, String? description}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final book = await ApiService.uploadBook(file, title, author: author, description: description);
      _books.insert(0, book);
      _isLoading = false;
      notifyListeners();
      return book;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// 获取详情
  Future<void> loadDetail(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _currentDetail = await ApiService.getBook(id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 刷新详情
  Future<void> refreshDetail() async {
    if (_currentDetail == null) return;
    try {
      _currentDetail = await ApiService.getBook(_currentDetail!.id);
      notifyListeners();
    } catch (_) {}
  }

  /// 删除有声书
  Future<bool> deleteBook(int id) async {
    try {
      await ApiService.deleteBook(id);
      _books.removeWhere((b) => b.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 创建 TTS 任务
  Future<Task?> createTask(int bookId) async {
    try {
      return await ApiService.createTask(bookId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
