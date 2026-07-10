import 'package:ai_audiobook_platform/features/library/services/book_repository_base.dart';
import 'package:ai_audiobook_platform/features/library/models/book.dart';

/// 内存书籍仓储：仅用于 Widget Test，完全不访问文件系统。
class FakeBookRepository extends BookRepositoryBase {
  final List<Book> _books;

  FakeBookRepository([List<Book>? books]) : _books = books ?? [];

  @override
  Future<List<Book>> loadAll() async => List<Book>.from(_books);

  @override
  Future<Book?> get(String id) async =>
      _books.where((b) => b.id == id).cast<Book>().firstOrNull;

  @override
  Future<Book> save(Book book) async {
    _books.removeWhere((b) => b.id == book.id);
    _books.add(book);
    return book;
  }

  @override
  Future<void> delete(String id) async =>
      _books.removeWhere((b) => b.id == id);
}
