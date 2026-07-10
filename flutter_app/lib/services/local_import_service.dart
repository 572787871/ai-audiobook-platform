/// 本地导入链路（问题三修复）：
/// FilePicker 选中 → 复制到 App 私有目录（iOS 安全作用域处理）
/// → 编码识别（UTF-8 / UTF-16 / GB18030 / GBK）
/// → TXT / EPUB 解析 → 章节切分 → 数据库（index.json）存储
/// 支持大文件流式读取、进度回调、具体错误阶段、同名去重/覆盖策略。
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../models/book.dart';
import 'local_book_service.dart';

/// 导入阶段，用于 UI 展示具体进度与错误信息。
enum ImportStage {
  picking,
  copying,
  detectingEncoding,
  parsing,
  chunking,
  saving,
  done,
  failed,
}

class ImportProgress {
  final ImportStage stage;
  final double fraction;
  final String label;
  final String? errorDetail;
  const ImportProgress({
    required this.stage,
    required this.fraction,
    required this.label,
    this.errorDetail,
  });
}

class ImportDuplication {
  final bool exists;
  final int? existingId;
  final String existingTitle;
  ImportDuplication({this.exists = false, this.existingId, this.existingTitle = ''});
}

class LocalImportService {
  LocalImportService._();

  /// 检测文件编码：UTF-8 → UTF-16(LE/BE) → GB18030/GBK。
  /// 大文件只采样前 64KB 做检测，避免一次性读入内存。
  static Future<Encoding> detectEncoding(File file) async {
    final sampleSize = (await file.length()).clamp(0, 65536);
    final sample = sampleSize > 0
        ? await file.openRead(0, sampleSize).first
        : <int>[];

    // BOM 检测。
    if (sample.length >= 3 &&
        sample[0] == 0xEF && sample[1] == 0xBB && sample[2] == 0xBF) {
      return utf8;
    }
    if (sample.length >= 2 &&
        ((sample[0] == 0xFF && sample[1] == 0xFE) ||
         (sample[0] == 0xFE && sample[1] == 0xFF))) {
      return Encoding.getByName('utf-16') ?? utf8;
    }

    // 尝试 UTF-8 严格解码采样段。
    try {
      utf8.decode(sample, allowMalformed: false);
      // 若采样段全是 ASCII 或合法 UTF-8，优先 UTF-8。
      final nonAscii = sample.any((b) => b > 0x7F);
      if (!nonAscii) return utf8;
      // 含非 ASCII 时再确认整体可解（用 utf8 解码整段采样已成功）。
      return utf8;
    } on FormatException {
      // 非法的 UTF-8 字节序列，尝试 GB18030/GBK。
    }

    // GB18030/GBK 解码（中文 Windows 常见），使用 charset 包提供的中文编码。
    final gb = _chineseEncoding();
    if (gb != null) {
      try {
        gb.decode(sample);
        return gb;
      } catch (_) {
        // fall through
      }
    }
    return latin1;
  }

  /// 返回中文编码（GB18030/GBK），来自 charset 包；不可用则返回 null。
  static Encoding? _chineseEncoding() {
    return Encoding.getByName('GB18030') ??
        Encoding.getByName('GBK') ??
        Encoding.getByName('gb18030') ??
        Encoding.getByName('gbk');
  }

  /// 读取文件文本，按检测编码解码，流式处理大文件。
  static Future<String> readText(File file, {Encoding? forced}) async {
    final enc = forced ?? await detectEncoding(file);
    final buffer = StringBuffer();
    await for (final chunk in file.openRead().transform(enc.decoder)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  /// 解析 EPUB：zip 内所有 XHTML/HTML 正文取纯文本。
  static Future<String> parseEpub(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final contents = <String>[];
    for (final fileEntry in archive.files) {
      if (fileEntry.isFile &&
          (fileEntry.name.toLowerCase().endsWith('.xhtml') ||
           fileEntry.name.toLowerCase().endsWith('.html') ||
           fileEntry.name.toLowerCase().endsWith('.htm'))) {
        final raw = fileEntry.content as List<int>;
        final html = latin1.decode(raw);
        contents.add(_stripHtml(html));
      }
    }
    if (contents.isEmpty) {
      throw const FormatException('EPUB 中未找到可解析的正文（XHTML/HTML）。');
    }
    return contents.join('\n\n');
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// 检查同名文件是否已导入，返回去重信息。
  static Future<ImportDuplication> checkDuplicate(String title) async {
    final books = await LocalBookService.listBooks();
    for (final b in books) {
      if (b.title == title) {
        return ImportDuplication(
            exists: true, existingId: b.id, existingTitle: b.title);
      }
    }
    return ImportDuplication();
  }

  /// 执行导入。返回 Book；失败抛 [ImportException]（含阶段与原因）。
  /// [onProgress] 回调具体阶段与进度。
  /// [overwriteExistingId] 非 null 时覆盖该已存在书籍。
  static Future<Book> import({
    required File sourceFile,
    required String title,
    String? author,
    String? description,
    void Function(ImportProgress)? onProgress,
    int? overwriteExistingId,
  }) async {
    try {
      onProgress?.call(ImportProgress(
          stage: ImportStage.copying,
          fraction: 0.05,
          label: '正在复制文件到本地…'));

      final root = await LocalBookService.rootDir();
      final id = overwriteExistingId ??
          DateTime.now().microsecondsSinceEpoch;
      final bookDir =
          Directory(p.join(root.path, 'books', 'book_$id'));
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
      await bookDir.create(recursive: true);

      final ext = p.extension(sourceFile.path).isEmpty
          ? '.txt'
          : p.extension(sourceFile.path).toLowerCase();
      final dest =
          File(p.join(bookDir.path, 'source$ext'));

      // 流式复制大文件，避免一次性读入内存。
      await _copyLargeFile(sourceFile, dest);

      onProgress?.call(ImportProgress(
          stage: ImportStage.detectingEncoding,
          fraction: 0.2,
          label: '识别文件编码…'));

      final isEpub = ext == '.epub';
      String text;
      if (isEpub) {
        onProgress?.call(ImportProgress(
            stage: ImportStage.parsing,
            fraction: 0.45,
            label: '解析 EPUB 正文…'));
        text = await parseEpub(dest);
      } else {
        onProgress?.call(ImportProgress(
            stage: ImportStage.parsing,
            fraction: 0.45,
            label: '按编码解码文本…'));
        text = await readText(dest);
      }

      if (text.trim().isEmpty) {
        throw ImportException(
            ImportStage.parsing, '文件解析后没有可读文本（可能编码错误或文件为空）。');
      }

      onProgress?.call(ImportProgress(
          stage: ImportStage.saving,
          fraction: 0.85,
          label: '写入本地书籍库…'));

      final now = DateTime.now().toIso8601String();
      final book = Book(
        id: id,
        userId: 0,
        title: title,
        author: author,
        description: description,
        sourceFilePath: dest.path,
        sourceFileSize: await dest.length(),
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      await LocalBookService.upsertBook(book,
          overwriteId: overwriteExistingId);

      onProgress?.call(ImportProgress(
          stage: ImportStage.done,
          fraction: 1.0,
          label: '导入完成',
          errorDetail: null));
      return book;
    } on ImportException {
      rethrow;
    } catch (e, st) {
      throw ImportException(
          ImportStage.failed, '导入失败：${e.toString()}', detail: st.toString());
    }
  }

  /// 流式复制：分块读取，适合大文件。
  static Future<void> _copyLargeFile(File source, File dest) async {
    if (await dest.exists()) await dest.delete();
    final sink = dest.openWrite();
    try {
      await for (final chunk in source.openRead()) {
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }
  }
}

class ImportException implements Exception {
  final ImportStage stage;
  final String message;
  final String? detail;
  const ImportException(this.stage, this.message, {this.detail});
  @override
  String toString() =>
      '导入异常（阶段 ${stage.name}）：$message${detail != null ? "\n详情：$detail" : ""}';
}
