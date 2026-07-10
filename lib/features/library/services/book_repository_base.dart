import '../models/book.dart';

/// 书籍仓储抽象接口，便于测试注入内存实现。
abstract class BookRepositoryBase {
  Future<List<Book>> loadAll();
  Future<Book?> get(String id);
  Future<void> delete(String id);
  Future<Book> save(Book book);
}
