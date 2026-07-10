/// Book Provider：有声书状态管理
import "package:flutter/foundation.dart";
import "dart:io";
import "../services/local_book_service.dart";
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
  /// 获取书籍详情
  Future<BookDetail> fetchBookDetail(int id) async {
    return LocalBookService.getBook(id);
  }

  Future<void> loadBooks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _books = await LocalBookService.listBooks();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 上传有声书
  Future<Book?> uploadBook(File file, String title,
      {String? author, String? description}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final book = await LocalBookService.importBook(file, title,
          author: author, description: description);
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
      _currentDetail = await LocalBookService.getBook(id);
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
      _currentDetail = await LocalBookService.getBook(_currentDetail!.id);
      notifyListeners();
    } catch (_) {}
  }

  /// 删除有声书
  Future<bool> deleteBook(int id) async {
    try {
      await LocalBookService.deleteBook(id);
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
    _error = "当前版本已关闭云端生成，请使用本地生成";
    notifyListeners();
    return null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
