import "dart:convert";
import "dart:io";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "../models/book.dart";
import "local_tts_service.dart";

class LocalBookService {
  LocalBookService._();

  static Future<List<Book>> listBooks() async {
    final books = await _readAll();
    books.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return books;
  }

  static Future<BookDetail> getBook(int id) async {
    final books = await _readAll();
    final book = books.firstWhere((b) => b.id == id);
    final text = await sourceText(book);
    final transcript = _transcriptFromText(text);
    final chapters = _chaptersFromTranscript(transcript);
    final segments = await LocalTtsService.getSegments(id);
    final duration = segments.isNotEmpty
        ? segments.fold<double>(0, (sum, seg) => sum + seg.duration)
        : book.audioDuration;
    return BookDetail(
      id: book.id,
      userId: book.userId,
      title: book.title,
      author: book.author,
      description: book.description,
      coverUrl: book.coverUrl,
      audioUrl: book.audioUrl,
      audioDuration: duration,
      sourceFilePath: book.sourceFilePath,
      sourceFileSize: book.sourceFileSize,
      status: segments.isNotEmpty ? "completed" : book.status,
      createdAt: book.createdAt,
      updatedAt: book.updatedAt,
      chapters: chapters,
      transcript: segments.isNotEmpty
          ? segments
              .map((s) => TranscriptLine(
                    start: s.startTime,
                    end: s.endTime,
                    text: s.originalText,
                  ))
              .toList()
          : transcript,
      wordCount: text.runes.length,
      totalDuration: duration?.toStringAsFixed(0),
    );
  }

  static Future<Book> importBook(
    File file,
    String title, {
    String? author,
    String? description,
  }) async {
    final root = await _rootDir();
    final id = DateTime.now().microsecondsSinceEpoch;
    final bookDir = Directory(p.join(root.path, "books", "book_$id"));
    await bookDir.create(recursive: true);
    final ext =
        p.extension(file.path).isEmpty ? ".txt" : p.extension(file.path);
    final dest = File(p.join(bookDir.path, "source$ext"));
    await file.copy(dest.path);
    final now = DateTime.now().toIso8601String();
    final imported = Book(
      id: id,
      userId: 0,
      title: title,
      author: author,
      description: description,
      sourceFilePath: dest.path,
      sourceFileSize: await dest.length(),
      status: "pending",
      createdAt: now,
      updatedAt: now,
    );
    final books = await _readAll();
    books.insert(0, imported);
    await _writeAll(books);
    return imported;
  }

  static Future<Book> markCompleted(int id, {double? duration}) async {
    final books = await _readAll();
    final idx = books.indexWhere((b) => b.id == id);
    if (idx < 0) throw StateError("本地书籍不存在");
    final now = DateTime.now().toIso8601String();
    final book = books[idx].copyWith(
      status: "completed",
      audioDuration: duration,
      updatedAt: now,
    );
    books[idx] = book;
    await _writeAll(books);
    return book;
  }

  static Future<void> deleteBook(int id) async {
    final books = await _readAll();
    books.removeWhere((b) => b.id == id);
    await _writeAll(books);
    final root = await _rootDir();
    final bookDir = Directory(p.join(root.path, "books", "book_$id"));
    if (await bookDir.exists()) await bookDir.delete(recursive: true);
    await LocalTtsService.deleteGeneratedAudio(id);
  }

  static Future<String> sourceText(Book book) async {
    final path = book.sourceFilePath;
    if (path == null || path.isEmpty) return book.description ?? book.title;
    final file = File(path);
    if (!await file.exists()) return book.description ?? book.title;
    return LocalTtsService.readTextFile(file);
  }

  static List<TranscriptLine> _transcriptFromText(String text) {
    final normalized = text
        .replaceAll("\r\n", "\n")
        .replaceAll("\r", "\n")
        .replaceAll(RegExp(r"<[^>]+>"), "")
        .trim();
    final lines = <TranscriptLine>[];
    final buffer = StringBuffer();
    var cursor = 0.0;
    for (final rune in normalized.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(char);
      if ("。！？!?；;\n".contains(char) || buffer.length >= 160) {
        final content = buffer.toString().trim();
        if (content.isNotEmpty) {
          final duration = (content.runes.length / 4.2).clamp(1.0, 60.0);
          lines.add(TranscriptLine(
              start: cursor, end: cursor + duration, text: content));
          cursor += duration;
        }
        buffer.clear();
      }
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      final duration = (tail.runes.length / 4.2).clamp(1.0, 60.0);
      lines.add(
          TranscriptLine(start: cursor, end: cursor + duration, text: tail));
    }
    return lines;
  }

  static List<Chapter> _chaptersFromTranscript(List<TranscriptLine> lines) {
    if (lines.isEmpty) return [];
    final result = <Chapter>[];
    for (var i = 0; i < lines.length; i += 30) {
      final group = lines.skip(i).take(30).toList();
      result.add(Chapter(
        index: result.length,
        title: group.first.text.length > 24
            ? "${group.first.text.substring(0, 24)}..."
            : group.first.text,
        start: group.first.start,
        end: group.last.end,
      ));
    }
    return result;
  }

  static Future<List<Book>> _readAll() async {
    final file = await _indexFile();
    if (!await file.exists()) return [];
    final data = jsonDecode(await file.readAsString()) as List;
    return data
        .map((e) => Book.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> _writeAll(List<Book> books) async {
    final file = await _indexFile();
    await file.writeAsString(jsonEncode(books.map((e) => e.toJson()).toList()));
  }

  static Future<File> _indexFile() async {
    final root = await _rootDir();
    final dir = Directory(p.join(root.path, "books"));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, "index.json"));
  }

  static Future<Directory> rootDir() => getApplicationDocumentsDirectory();

  /// 写入或更新一本书（覆盖时替换同 id 记录）。
  static Future<void> upsertBook(Book book, {int? overwriteId}) async {
    final books = await _readAll();
    if (overwriteId != null) {
      books.removeWhere((b) => b.id == overwriteId);
    } else {
      books.removeWhere((b) => b.id == book.id);
    }
    books.insert(0, book);
    await _writeAll(books);
  }

  static Future<Directory> _rootDir() => getApplicationDocumentsDirectory();
}
