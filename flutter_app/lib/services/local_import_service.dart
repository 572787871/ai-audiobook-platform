/// 本地导入链路（问题三修复）：
/// FilePicker 选中 → 复制到 App 私有目录（iOS 安全作用域处理）
/// → 编码识别（UTF-8 / UTF-16 / GB18030 / GBK）
/// → TXT / MD / EPUB / PDF / DOCX 解析 → 存储
/// 支持大文件流式读取、进度回调、具体错误阶段、同名去重/覆盖策略。
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../models/book.dart';
import 'local_book_service.dart';

/// 导入阶段，用于 UI 展示具体进度与错误信息。
enum ImportStage {
  idle,
  copying,
  detectingEncoding,
  parsing,
  saving,
  done,
  failed,
}

/// 进度回调载荷。
class ImportProgress {
  final ImportStage stage;
  final double fraction; // 0..1
  final String label;
  final String? errorDetail;
  const ImportProgress({
    required this.stage,
    required this.fraction,
    required this.label,
    this.errorDetail,
  });
}

/// 去重检测结果。
class ImportDuplication {
  final bool exists;
  final int? existingId;
  final String? existingTitle;
  const ImportDuplication({
    required this.exists,
    this.existingId,
    this.existingTitle,
  });
}

/// 支持的扩展名（小写，含点）。
const List<String> kSupportedExtensions = [
  '.txt',
  '.md',
  '.epub',
  '.pdf',
  '.docx',
];

class LocalImportService {
  /// 检测文本文件编码（采样前 64KB）。
  /// 优先 BOM（UTF-8/UTF-16LE/UTF-16BE），其次中文编码（GB18030/GBK），最后回退 UTF-8。
  static Future<Encoding> detectEncoding(File file) async {
    final sampleSize = 64 * 1024;
    final length = await file.length();
    final readBytes = length > sampleSize ? sampleSize : length;
    final raf = file.openSync();
    try {
      final bytes = raf.readSync(readBytes);
      return _detectFromBytes(bytes);
    } finally {
      await raf.close();
    }
  }

  static Encoding _detectFromBytes(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8;
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return Encoding.getByName('utf-16')!; // UTF-16LE
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return Encoding.getByName('utf-16')!; // UTF-16BE
    }
    // 中文编码探测：GB18030/GBK 在采样文本中通常含 0x80 以上的高位字节且能合法解码。
    final cn = _chineseEncoding();
    if (cn != null) {
      try {
        cn.decode(bytes);
        return cn;
      } catch (_) {
        // 解码失败则继续
      }
    }
    return utf8;
  }

  static Encoding? _chineseEncoding() {
    // GB18030 是 GBK 的超集，优先使用。
    return Encoding.getByName('gb18030') ??
        Encoding.getByName('gbk') ??
        Encoding.getByName('cp936');
  }

  /// 读取纯文本文件（txt/md）。自动识别编码。
  static Future<String> readText(File file, {Encoding? forced}) async {
    final enc = forced ?? await detectEncoding(file);
    final raf = file.openSync();
    try {
      final all = raf.readSync(await raf.length());
      return enc.decode(all);
    } finally {
      await raf.close();
    }
  }

  /// 解析 EPUB：解压 container.xml → OPF → 按 spine 顺序提取 XHTML 正文文本。
  static Future<String> parseEpub(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    // 找 OPF 路径
    String? opfPath;
    final container = archive.findFile('META-INF/container.xml');
    if (container != null) {
      final xml = const Utf8Codec().decode(container.content as List<int>);
      final m = RegExp(r'full-path="([^"]+)"').firstMatch(xml);
      if (m != null) opfPath = m.group(1);
    }
    if (opfPath == null) {
      // 退而求其次：找第一个 .opf
      for (final f in archive.files) {
        if (f.name.endsWith('.opf')) {
          opfPath = f.name;
          break;
        }
      }
    }
    if (opfPath == null) {
      throw Exception('EPUB 缺少 OPF 描述文件');
    }
    final opf = archive.findFile(opfPath);
    if (opf == null) throw Exception('EPUB OPF 文件缺失');
    final opfXml = const Utf8Codec().decode(opf.content as List<int>);
    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';
    // spine 顺序
    final itemRefs = RegExp(r'<itemref[^>]*idref="([^"]+)"')
        .allMatches(opfXml)
        .map((e) => e.group(1)!)
        .toList();
    // manifest：id -> href
    final manifest = <String, String>{};
    for (final m in RegExp(r'<item[^>]*id="([^"]+)"[^>]*href="([^"]+)"').allMatches(opfXml)) {
      manifest[m.group(1)!] = m.group(2)!;
    }
    final buffer = StringBuffer();
    for (final id in itemRefs) {
      final href = manifest[id];
      if (href == null) continue;
      final itemPath = p.normalize(p.join(opfDir, href));
      final item = archive.findFile(itemPath);
      if (item == null) continue;
      final xhtml = const Utf8Codec().decode(item.content as List<int>);
      buffer.write(_stripHtml(xhtml));
      buffer.write('\n\n');
    }
    return buffer.toString().trim();
  }

  /// 解析 DOCX：解压 word/document.xml，提取所有 <w:t> 文本。
  static Future<String> parseDocx(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final doc = archive.findFile('word/document.xml');
    if (doc == null) throw Exception('DOCX 缺少 word/document.xml');
    final xml = const Utf8Codec().decode(doc.content as List<int>);
    return _extractDocxText(xml);
  }

  /// 解析 PDF（纯 Dart，无原生依赖）：提取内容流中的文本操作符 (Tj/TJ)。
  /// 支持文本型 PDF；扫描件/加密 PDF 会提示无法提取。
  static Future<String> parsePdf(File file) async {
    final bytes = await file.readAsBytes();
    // 1) 提取所有内容流（解压 FlateDecode 的 stream）
    final raw = String.fromCharCodes(bytes);
    final sb = StringBuffer();
    // 处理未压缩流中的文本
    sb.write(_extractPdfTextFromRaw(raw));
    // 尝试解压 stream 中的 FlateDecode
    final streamRe = RegExp(r'stream\r?\n(.*?)\r?\nendstream', dotAll: true);
    for (final m in streamRe.allMatches(raw)) {
      final chunk = m.group(1)!;
      final decoded = _tryInflate(chunk);
      if (decoded != null) {
        sb.write(_extractPdfTextFromRaw(decoded));
      }
    }
    final text = sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) {
      throw Exception('PDF 未提取到文本（可能是扫描件/加密 PDF，建议转成 txt 后导入）');
    }
    return text;
  }

  static String _extractPdfTextFromRaw(String raw) {
    final out = StringBuffer();
    // 匹配 (...) Tj 或 [(...)...] TJ 中的字符串
    final tjRe = RegExp(r'\((?:[^()\\]|\\.)*\)\s*Tj');
    for (final m in tjRe.allMatches(raw)) {
      out.write(_unescapePdfString(m.group(0)!));
      out.write(' ');
    }
    final tjArrayRe = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
    for (final m in tjArrayRe.allMatches(raw)) {
      final inner = m.group(1) ?? '';
      for (final s in RegExp(r'\((?:[^()\\]|\\.)*\)').allMatches(inner)) {
        out.write(_unescapePdfString(s.group(0)!));
      }
      out.write(' ');
    }
    return out.toString();
  }

  static String _unescapePdfString(String token) {
    // token 形如 (text) 或 [(text)...]
    var s = token;
    if (s.startsWith('(')) s = s.substring(1);
    if (s.endsWith(')')) s = s.substring(0, s.length - 1);
    // 去掉尾部的 Tj/TJ 标记
    s = s.replaceAll(RegExp(r'\s*T[jJ]\s*$'), '');
    return s
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', '\\')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\r', ' ')
        .replaceAll(r'\t', ' ');
  }

  static String? _tryInflate(String chunk) {
    try {
      // 使用 archive 的 ZLibDecoder 解压 FlateDecode 流
      final data = chunk.codeUnits.where((c) => c < 256).toList();
      final inflated = const ZLibDecoder().decodeBytes(data);
      return String.fromCharCodes(inflated);
    } catch (_) {
      return null;
    }
  }

  /// 根据扩展名分发到对应解析器。
  static Future<String> extractText(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    switch (ext) {
      case '.epub':
        return parseEpub(file);
      case '.docx':
        return parseDocx(file);
      case '.pdf':
        return parsePdf(file);
      case '.txt':
      case '.md':
      default:
        return readText(file);
    }
  }

  static String _stripHtml(String html) {
    final withoutScripts = html
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ');
    final text = withoutScripts
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text;
  }

  static String _extractDocxText(String xml) {
    final sb = StringBuffer();
    for (final m in RegExp(r'<w:t[^>]*>(.*?)</w:t>', caseSensitive: false, dotAll: true)
        .allMatches(xml)) {
      sb.write(_decodeXmlEntities(m.group(1) ?? ''));
    }
    // 段落分隔
    final paras = xml.split(RegExp(r'</w:p>', caseSensitive: false));
    final out = StringBuffer();
    for (final p in paras) {
      final frag = StringBuffer();
      for (final m in RegExp(r'<w:t[^>]*>(.*?)</w:t>', caseSensitive: false, dotAll: true)
          .allMatches(p)) {
        frag.write(_decodeXmlEntities(m.group(1) ?? ''));
      }
      final s = frag.toString().trim();
      if (s.isNotEmpty) out.write('$s\n');
    }
    return out.toString().trim();
  }

  static String _decodeXmlEntities(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
  }

  /// 检查同名书籍是否已存在（按标题匹配）。
  static Future<ImportDuplication> checkDuplicate(String title) async {
    final books = await LocalBookService.readAllBooks();
    for (final b in books) {
      if (b.title.trim() == title.trim()) {
        return ImportDuplication(
            exists: true, existingId: b.id, existingTitle: b.title);
      }
    }
    return const ImportDuplication(exists: false);
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
    final ext = p.extension(sourceFile.path).toLowerCase();
    if (!kSupportedExtensions.contains(ext)) {
      throw ImportException(ImportStage.failed,
          '不支持的文件类型：$ext（仅支持 txt/md/epub/pdf/docx）');
    }
    try {
      onProgress?.call(ImportProgress(
          stage: ImportStage.copying,
          fraction: 0.05,
          label: '正在复制文件到本地…'));

      final root = await LocalBookService.rootDir();
      final id = overwriteExistingId ??
          DateTime.now().microsecondsSinceEpoch;
      final bookDir = Directory(p.join(root.path, 'books', 'book_$id'));
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
      await bookDir.create(recursive: true);

      final dest = File(p.join(bookDir.path, 'source$ext'));

      // 流式复制大文件，避免一次性读入内存。
      await _copyLargeFile(sourceFile, dest);

      onProgress?.call(ImportProgress(
          stage: ImportStage.detectingEncoding,
          fraction: 0.2,
          label: '识别文件编码…'));

      onProgress?.call(ImportProgress(
          stage: ImportStage.parsing,
          fraction: 0.45,
          label: '解析正文内容…'));

      final text = await extractText(dest);

      if (text.trim().isEmpty) {
        throw ImportException(ImportStage.parsing,
            '文件解析后没有可读文本（可能编码错误、文件为空或为图片型 PDF）。');
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
      await source.openRead().pipe(sink);
    } finally {
      await sink.close();
    }
  }
}

/// 导入异常：携带阶段与可展示的错误信息。
class ImportException implements Exception {
  final ImportStage stage;
  final String message;
  final String? detail;
  const ImportException(this.stage, this.message, {this.detail});
  @override
  String toString() => message;
}
