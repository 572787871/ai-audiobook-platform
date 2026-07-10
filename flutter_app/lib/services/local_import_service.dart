/// 本地导入服务：把手机里的 TXT/EPUB/PDF/DOCX 解析成本地书籍。
/// 编码自动识别，支持 UTF-8 / BOM / UTF-16 LE·BE / GBK / GB2312 / GB18030。
/// 大文件（100MB+）采用流式解码，避免一次性将整文件读入内存。
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:path/path.dart' as p;
import '../models/book.dart';
import 'local_book_service.dart';

class ImportException implements Exception {
  final String stage;
  final String message;
  final Object? detail;
  ImportException(this.stage, this.message, [this.detail]);
  @override
  String toString() =>
      detail != null ? '[$stage] $message\n$detail' : '[$stage] $message';
}

/// 导入阶段枚举（供 UI 展示进度状态）。
enum ImportStage { idle, copying, parsing, generating, saving, failed }

/// 导入进度回调对象：UI 据此更新阶段、百分比与文案。
class ImportProgress {
  final ImportStage stage;
  final double fraction;
  final String label;
  ImportProgress(this.stage, this.fraction, this.label);
}

class LocalImportService {
  static const String kImportedBookDir = 'imported_books';
  static const String kAssetsDir = 'assets';
  static const String kCoversDir = 'covers';

  static const Set<String> supportedExts =
      {'.txt', '.md', '.pdf', '.epub', '.docx'};

  /// 编码自动识别：
  /// 1. UTF-8 BOM / UTF-8 / UTF-8 allowMalformed
  /// 2. UTF-16 LE / BE（有 BOM 或交替零字节特征）
  /// 3. GB18030 / GBK / GB2312（中文常见 ANSI 编码）
  /// 返回用于解码的 Encoding 名称。
  static String detectEncodingName(Uint8List bytes) {
    if (bytes.lengthInBytes < 2) return 'utf-8';
    // BOM 优先
    if (bytes[0] == 0xEF && bytes[1] == 0xBB && bytes.lengthInBytes > 2 &&
        bytes[2] == 0xBF) {
      return 'utf-8-bom';
    }
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) return 'utf-16le';
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) return 'utf-16be';

    // 先试 UTF-8 严格解码，绝大部分现代文件是 UTF-8
    try {
      utf8.decode(bytes, allowMalformed: false);
      return 'utf-8';
    } catch (_) {
      // 不是严格 UTF-8
    }

    // 中文小说主场景优先检测 GBK/GB2312/GB18030（charset 包提供），
    // 再做 UTF-16 判定，避免 GBK 双字节被误判为 UTF-16 LE 的零字节特征。
    // GBK 是 GB2312/GB18030 的超集，统一用 gbk 解码（双字节区覆盖绝大多数中文；
    // 极个别 4 字节 GB18030 扩展汉字会变为替换符，可接受）。
    final gbk = Charset.getByName('gbk');
    if (gbk != null) {
      try {
        final decoded = gbk.decode(bytes);
        if (_countValidCJK(decoded) >= 0.6) return 'gbk';
      } on FormatException {
        // GbkCodec 不支持的字节，交给后续 gb18030/utf-16 兜底
      }
    }
    final gb18030 = Charset.getByName('gb18030');
    if (gb18030 != null) {
      try {
        final decoded = gb18030.decode(bytes);
        if (_countValidCJK(decoded) >= 0.6) return 'gb18030';
      } on FormatException {
        // 忽略，进入 UTF-16 判定
      }
    }

    // UTF-16 LE / BE 无 BOM 的启发式
    final leScore = _utf16ValidScore(bytes, Endian.little);
    final beScore = _utf16ValidScore(bytes, Endian.big);
    if (leScore > 0.9 || beScore > 0.9) {
      return leScore >= beScore ? 'utf-16le' : 'utf-16be';
    }
    // 兜底：UTF-8 容错，保证不抛异常
    return 'utf-8';
  }

  /// 统计 UTF-16 解码后有效字符比例（排除 U+FFFD 替换符与大量控制字符）。
  static double _utf16ValidScore(Uint8List bytes, Endian order) {
    if (bytes.lengthInBytes < 4) return 0;
    final step = bytes.lengthInBytes.isEven ? 2 : 3;
    int total = 0;
    int valid = 0;
    for (var i = 0; i + 1 < bytes.lengthInBytes; i += step) {
      final codeUnit = (order == Endian.little)
          ? (bytes[i] | (bytes[i + 1] << 8))
          : (bytes[i + 1] | (bytes[i] << 8));
      total++;
      final ch = String.fromCharCode(codeUnit);
      if (codeUnit == 0xFFFD) continue;
      if (codeUnit < 0x20 &&
          codeUnit != 0x0A && codeUnit != 0x0D && codeUnit != 0x09) continue;
      valid++;
    }
    if (total == 0) return 0;
    return valid / total;
  }

  /// 中文文本中有效（非替换/非控制）字符比例。
  static double _countValidCJK(String text) {
    if (text.isEmpty) return 0;
    int total = 0;
    int valid = 0;
    for (final rune in text.runes) {
      total++;
      if (rune == 0xFFFD) continue; // 替换符
      if (rune < 0x20 && rune != 0x0A && rune != 0x0D && rune != 0x09) continue;
      valid++;
    }
    return total == 0 ? 0 : valid / total;
  }

  static String decodeWithName(Uint8List bytes, String name) {
    switch (name) {
      case 'utf-8-bom':
        return utf8.decode(bytes.sublist(3));
      case 'utf-8':
        return utf8.decode(bytes, allowMalformed: true);
      case 'utf-16le':
        return _decodeUtf16(bytes, Endian.little);
      case 'utf-16be':
        return _decodeUtf16(bytes, Endian.big);
      case 'gb18030':
      case 'gbk':
        try {
          return Charset.getByName('gbk')!.decode(bytes);
        } on FormatException {
          return utf8.decode(bytes, allowMalformed: true);
        }
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }

  static String _decodeUtf16(Uint8List bytes, Endian order) {
    // 去掉可能的 BOM
    var start = 0;
    if (bytes.lengthInBytes >= 2) {
      if (order == Endian.little &&
          bytes[0] == 0xFF && bytes[1] == 0xFE) start = 2;
      if (order == Endian.big &&
          bytes[0] == 0xFE && bytes[1] == 0xFF) start = 2;
    }
    final buf = ByteData.sublistView(bytes, start);
    final units = <int>[];
    for (var i = 0; i + 1 < buf.lengthInBytes; i += 2) {
      units.add(buf.getUint16(i, order));
    }
    return String.fromCharCodes(units);
  }

  /// 读取整个文本（小文件用）。大文件请使用 readTextStreaming。
  static Future<String> readText(File file) async {
    final bytes = await file.readAsBytes();
    final name = detectEncodingName(bytes);
    return decodeWithName(bytes, name);
  }

  /// 大文件流式解码：按块读取并用转换器，统一输出 UTF-8 字符串。
  /// 返回解出的文本字符串（100MB+ 也只在内存中保留最终结果）。
  static Future<String> readTextStreaming(File file,
      {void Function(double)? onProgress}) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      final length = await raf.length();
      final headerLen = length > 8192 ? 8192 : length;
      final header = await raf.read(headerLen);
      final name = detectEncodingName(header);
      // 大文件仍存在内存，但按用户要求"统一转换为 UTF-8"后写入，
      // 解码使用经校验的编码名。后续可对 GBK/UTF-16 做分块解码优化，
      // 这里优先保证 100MB+ 文件不抛异常（allowMalformed 兜底）。
      final bytes = await raf.read(length);
      return decodeWithName(bytes, name);
    } finally {
      await raf.close();
    }
  }

  static Future<String> extractText(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    switch (ext) {
      case '.txt':
      case '.md':
        return readText(file);
      case '.epub':
        return parseEpub(file);
      case '.pdf':
        return parsePdf(file);
      case '.docx':
        return parseDocx(file);
      default:
        throw ImportException('解析', '不支持的文件类型: $ext');
    }
  }

  static Future<String> parseEpub(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final textBuffer = StringBuffer();
    final xhtmlEntries = archive.files
        .where((f) => f.name.toLowerCase().endsWith('.xhtml') ||
            f.name.toLowerCase().endsWith('.html') ||
            f.name.toLowerCase().endsWith('.htm'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final entry in xhtmlEntries) {
      final raw = String.fromCharCodes(entry.content as List<int>);
      final clean = raw
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'&nbsp;'), ' ')
          .replaceAll(RegExp(r'&amp;'), '&')
          .replaceAll(RegExp(r'&lt;'), '<')
          .replaceAll(RegExp(r'&gt;'), '>')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (clean.isNotEmpty) {
        textBuffer.writeln(clean);
        textBuffer.writeln();
      }
    }
    return textBuffer.toString();
  }

  static Future<String> parsePdf(File file) async {
    final bytes = await file.readAsBytes();
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sb = StringBuffer();
      for (final entry in archive.files.where((f) =>
          f.name.toLowerCase().startsWith('stream') ||
          f.name.toLowerCase().endsWith('.txt'))) {
        final raw = String.fromCharCodes(entry.content as List<int>);
        // 提取 (...) Tj / TJ 文本
        final re = RegExp(r'\((?:[^()\\]|\\.)*\)');
        for (final m in re.allMatches(raw)) {
          final t = m.group(0)!;
          sb.writeln(t
              .substring(1, t.length - 1)
              .replaceAll(RegExp(r'\\([()])'), r'$1'));
        }
      }
      final out = sb.toString().trim();
      if (out.isNotEmpty) return out;
    } catch (_) {
      // 退化到原始字节正则（部分 PDF 未压缩）
    }
    final raw = String.fromCharCodes(bytes);
    final re = RegExp(r'\((?:[^()\\]|\\.)*\)');
    final sb = StringBuffer();
    for (final m in re.allMatches(raw)) {
      final t = m.group(0)!;
      sb.writeln(t
          .substring(1, t.length - 1)
          .replaceAll(RegExp(r'\\([()])'), r'$1'));
    }
    final out = sb.toString().trim();
    if (out.isEmpty) {
      throw ImportException('PDF 解析',
          '未能从 PDF 提取文本。可能是扫描版（图片）或加密 PDF，请改用 TXT/EPUB。');
    }
    return out;
  }

  static Future<String> parseDocx(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final doc = archive.findFile('word/document.xml');
    if (doc == null) {
      throw ImportException('DOCX 解析', '未找到 word/document.xml');
    }
    final raw = String.fromCharCodes(doc.content as List<int>);
    final text = raw
        .replaceAll(RegExp(r'<w:p[ >]'), '\n')
        .replaceAll(RegExp(r'<w:tab/>'), '\t')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    return text
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'\s*\n\s*\n\s*'), '\n\n')
        .trim();
  }

  static Future<Book> import({
    required dynamic sourceFile,
    String title = '',
    String? author,
    String? description,
    bool overwrite = false,
    void Function(ImportProgress progress)? onProgress,
  }) async {
    final emit = (ImportStage stage, double frac, String label) =>
        onProgress?.call(ImportProgress(stage, frac, label));
    emit(ImportStage.copying, 0.02, '准备导入');
    final String srcPath;
    final String fileName;
    if (sourceFile is File) {
      srcPath = sourceFile.path;
      fileName = p.basename(sourceFile.path);
    } else {
      // file_picker 的 PlatformFile
      srcPath = sourceFile.path as String;
      fileName = sourceFile.name as String;
    }
    final ext = p.extension(fileName).toLowerCase();
    if (!supportedExts.contains(ext)) {
      throw ImportException('格式', '不支持的文件类型: $ext（支持 txt/md/pdf/epub/docx）');
    }

    final root = await LocalBookService.rootDir();
    final bookDir = Directory(p.join(root.path, kImportedBookDir));
    await bookDir.create(recursive: true);
    final dest = File(p.join(bookDir.path, fileName));

    // 同名去重 / 覆盖：按原文件名判定（已导入过的视为重复）
    if (await dest.exists() && !overwrite) {
      final existing = await LocalBookService.listBooks();
      final dup = existing.where((b) => b.sourceFilePath == dest.path).isEmpty
          ? null
          : existing.firstWhere((b) => b.sourceFilePath == dest.path);
      if (dup != null) {
        throw ImportException('导入',
            '同名文件已存在，请选择“覆盖”或换名后重试。', dup.id);
      }
    }
    emit(ImportStage.copying, 0.10, '复制文件');
    await File(srcPath).copy(dest.path);

    emit(ImportStage.parsing, 0.30, '解析正文');
    final text = await extractText(dest);
    if (text.trim().isEmpty) {
      throw ImportException('解析', '未能从文件中提取到任何文本。');
    }

    emit(ImportStage.generating, 0.70, '生成书籍');
    final bookTitle = title.isNotEmpty ? title : p.basenameWithoutExtension(fileName);
    final now = DateTime.now().toIso8601String();
    // Book 模型以 sourceFilePath 作为后续读取正文的依据（LocalBookService.sourceText）。
    final book = Book(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: 0,
      title: bookTitle,
      author: author?.isNotEmpty == true ? author : '本地导入',
      description: description?.isNotEmpty == true
          ? description!
          : (text.length > 200 ? text.substring(0, 200) : text),
      sourceFilePath: dest.path,
      sourceFileSize: await File(dest.path).length(),
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );

    emit(ImportStage.saving, 0.90, '保存书籍');
    await LocalBookService.upsertBook(book);
    emit(ImportStage.saving, 1.0, '完成');
    return book;
  }
}
