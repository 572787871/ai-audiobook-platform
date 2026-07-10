import 'dart:convert';
import 'dart:io';
import 'book_repository_base.dart';
export 'book_repository_base.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';

/// 书籍仓储抽象接口。
/// 生产环境使用 [BookRepository]（基于文件系统的实现）；
/// 测试可注入内存实现，避免访问设备路径或触发平台插件。
/// 书籍本地仓储：负责书籍目录、book.json、index.json 的读写与恢复。
///
/// 存储结构：
///   Application Support/books/index.json
///   Application Support/books/{bookId}/original.{ext}
///   Application Support/books/{bookId}/content.txt  (仅 TXT)
///   Application Support/books/{bookId}/book.json
class BookRepository implements BookRepositoryBase {
  BookRepository._();

  static BookRepository? _instance;
  static BookRepository get instance => _instance ??= BookRepository._();

  Directory? _booksDir;
  File? _indexFile;
  final Map<String, Book> _cache = {};

  /// 初始化：定位 Application Support/books 目录。可注入基础目录用于测试。
  ///
  /// 在原生平台通过 [getApplicationSupportDirectory] 获取；若该插件不可用
  /// （例如单元测试宿主），降级到系统临时目录，保证逻辑可运行不崩溃。
  Future<Directory> getBooksDir() async {
    if (_booksDir != null) return _booksDir!;
    Directory appSupport;
    try {
      appSupport = await getApplicationSupportDirectory();
    } catch (_) {
      appSupport = Directory.systemTemp;
    }
    final dir = Directory(p.join(appSupport.path, 'books'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _booksDir = dir;
    _indexFile = File(p.join(dir.path, 'index.json'));
    return dir;
  }

  /// 测试用：直接指定目录（绕过 getApplicationSupportDirectory）
  void setBooksDirForTest(Directory dir) {
    _booksDir = dir;
    _indexFile = File(p.join(dir.path, 'index.json'));
    _cache.clear();
  }

  /// 测试用：重置单例内存状态，避免测试间共享。
  void resetForTest() {
    _booksDir = null;
    _indexFile = null;
    _cache.clear();
  }

  File _bookJsonFile(String bookId) =>
      File(p.join(_booksDir!.path, bookId, 'book.json'));

  @override
  Future<List<Book>> loadAll() async {
    await getBooksDir();
    final books = <Book>[];
    _cache.clear();

    // 优先从 index.json 读取 id 列表
    List<String> ids = [];
    if (_indexFile != null && await _indexFile!.exists()) {
      try {
        final raw = await _indexFile!.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          ids = decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        // index 损坏：扫描目录重建
        ids = await _scanBookIds();
      }
    } else {
      ids = await _scanBookIds();
    }

    for (final id in ids) {
      final book = await _readBook(id);
      if (book != null) {
        // 文件缺失则跳过（不崩溃）
        final original = File(book.originalPath);
        if (await original.exists()) {
          books.add(book);
          _cache[id] = book;
        }
      }
    }

    // 若 index 与扫描不一致，重写 index
    await _saveIndex(books.map((b) => b.id).toList());
    return books;
  }

  Future<List<String>> _scanBookIds() async {
    final ids = <String>[];
    final dir = await getBooksDir();
    final entries = dir.listSync().whereType<Directory>();
    for (final e in entries) {
      final name = p.basename(e.path);
      if (name == 'books') continue;
      ids.add(name);
    }
    return ids;
  }

  Future<Book?> _readBook(String id) async {
    final f = _bookJsonFile(id);
    if (!await f.exists()) return null;
    try {
      final raw = await f.readAsString();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return Book.fromJson(json);
    } catch (e) {
      // 损坏记录：记录日志并跳过
      // ignore: avoid_print
      print('[BookRepository] 跳过损坏记录: $id, 错误: $e');
      return null;
    }
  }

  @override
  Future<Book> save(Book book) async {
    await getBooksDir();
    final bookDir = Directory(p.join(_booksDir!.path, book.id));
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }
    final f = _bookJsonFile(book.id);
    await f.writeAsString(jsonEncode(book.toJson()));
    _cache[book.id] = book;
    await _appendToIndex(book.id);
    return book;
  }

  @override
  Future<Book?> get(String id) async {
    if (_cache.containsKey(id)) return _cache[id];
    final book = await _readBook(id);
    if (book != null) _cache[id] = book;
    return book;
  }

  @override
  Future<void> delete(String id) async {
    await getBooksDir();
    final bookDir = Directory(p.join(_booksDir!.path, id));
    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }
    _cache.remove(id);
    await _removeFromIndex(id);
  }

  Future<void> _saveIndex(List<String> ids) async {
    if (_indexFile == null) return;
    await _indexFile!.writeAsString(jsonEncode(ids));
  }

  Future<void> _appendToIndex(String id) async {
    final current = _cache.keys.toList();
    if (!current.contains(id)) current.add(id);
    await _saveIndex(current);
  }

  Future<void> _removeFromIndex(String id) async {
    final current = _cache.keys.toList();
    current.remove(id);
    await _saveIndex(current);
  }
}
