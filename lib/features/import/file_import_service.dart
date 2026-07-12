import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../library/models/book.dart';
import '../library/models/book_file_type.dart';
import '../library/models/book_parse_status.dart';
import '../library/services/book_repository.dart';
import '../../shared/services/file_hash_service.dart';
import '../../shared/services/text_encoding_service.dart';
import 'file_import_result.dart';
import 'import_progress.dart';

/// 各格式大小限制（字节）
const Map<BookFileType, int> _maxSize = {
  BookFileType.txt: 100 * 1024 * 1024, // 100 MB
  BookFileType.epub: 500 * 1024 * 1024, // 500 MB
  BookFileType.pdf: 500 * 1024 * 1024, // 500 MB
  BookFileType.docx: 200 * 1024 * 1024, // 200 MB
};

/// 本地文件导入服务：选择 → 校验 → 复制 → 建 Book → 保存。
///
/// 注意：本阶段只完成文件选择（调用方传入 [File]）与本地落盘逻辑，
/// 文件选择器 UI 由页面层使用 file_picker 调用。
class FileImportService {
  FileImportService._();

  static FileImportService? _instance;
  static FileImportService get instance => _instance ??= FileImportService._();

  final _uuid = const Uuid();

  /// 从平台选中的文件导入。
  ///
  /// [sourceFile] 为选定的源文件。
  /// [onProgress] 可选，用于推送进度。
  /// [forceImport] 为 true 时忽略重复检测。
  Future<FileImportResult> importFile(
    File sourceFile, {
    void Function(ImportProgress)? onProgress,
    bool forceImport = false,
  }) async {
    try {
      onProgress?.call(
        const ImportProgress(state: ImportProgressState.validating),
      );

      // 1. 文件存在性
      if (!await sourceFile.exists()) {
        return const FileImportResult(
          success: false,
          errorCode: FileImportErrorCode.fileNotFound,
          errorMessage: '文件不存在',
        );
      }

      // 2. 空文件
      final fileSize = await sourceFile.length();
      if (fileSize == 0) {
        return const FileImportResult(
          success: false,
          errorCode: FileImportErrorCode.emptyFile,
          errorMessage: '文件为空，无法导入',
        );
      }

      // 3. 扩展名
      final ext = p.extension(sourceFile.path);
      final fileType = BookFileType.fromExtension(ext);
      if (fileType == null) {
        return FileImportResult(
          success: false,
          errorCode: FileImportErrorCode.unsupportedExtension,
          errorMessage: '不支持的文件格式：$ext',
        );
      }

      // 4. 大小限制
      final limit = _maxSize[fileType]!;
      if (fileSize > limit) {
        return FileImportResult(
          success: false,
          errorCode: FileImportErrorCode.tooLarge,
          errorMessage: '文件过大（最大 ${_formatLimit(limit)}），请压缩后重试',
        );
      }

      // 5. 重复检测（文件名 + 大小 + SHA-256）
      if (!forceImport) {
        final dup = await _checkDuplicate(sourceFile, fileSize, fileType);
        if (dup != null) {
          return FileImportResult(
            success: false,
            errorCode: FileImportErrorCode.duplicate,
            errorMessage: '这本书似乎已经导入过了',
            existingBookId: dup,
          );
        }
      }

      // 6. 复制到沙盒
      onProgress?.call(
        const ImportProgress(state: ImportProgressState.copying),
      );
      final repo = BookRepository.instance;
      final booksDir = await repo.getBooksDir();
      final bookId = _uuid.v4();
      final bookDir = Directory(p.join(booksDir.path, bookId));
      await bookDir.create(recursive: true);

      final originalName = p.basename(sourceFile.path);
      final originalTarget = File(
        p.join(bookDir.path, 'original.${fileType.extension}'),
      );
      await sourceFile.copy(originalTarget.path);

      final now = DateTime.now();
      Book book;

      if (fileType == BookFileType.txt) {
        // TXT：解码 + 统计字符 + 保存 content.txt
        onProgress?.call(
          const ImportProgress(state: ImportProgressState.decoding),
        );
        final rawBytes = await originalTarget.readAsBytes();
        final decoded = await TextEncodingService.decodeBytesAsync(rawBytes);
        final contentTarget = File(p.join(bookDir.path, 'content.txt'));
        await contentTarget.writeAsString(decoded.text, encoding: utf8);
        final charCount = decoded.text.length;

        book = Book(
          id: bookId,
          title: _titleFromFileName(originalName),
          originalFileName: originalName,
          fileType: fileType,
          originalPath: originalTarget.path,
          contentPath: contentTarget.path,
          fileSize: fileSize,
          characterCount: charCount,
          encoding: decoded.encoding,
          createdAt: now,
          updatedAt: now,
          parseStatus: BookParseStatus.ready,
          chapterCount: 0,
        );
      } else {
        // EPUB / PDF / DOCX：仅保存，等待后续解析
        book = Book(
          id: bookId,
          title: _titleFromFileName(originalName),
          originalFileName: originalName,
          fileType: fileType,
          originalPath: originalTarget.path,
          fileSize: fileSize,
          createdAt: now,
          updatedAt: now,
          parseStatus: BookParseStatus.pending,
          chapterCount: 0,
        );
      }

      // 7. 保存记录
      onProgress?.call(const ImportProgress(state: ImportProgressState.saving));
      await repo.save(book);

      onProgress?.call(const ImportProgress(state: ImportProgressState.done));
      return FileImportResult(success: true, book: book);
    } catch (e) {
      final msg = e is EncodingException ? '无法识别文件编码，可能是乱码或尚不支持的编码' : '导入失败：$e';
      return FileImportResult(
        success: false,
        errorCode: e is EncodingException
            ? FileImportErrorCode.encodingFailed
            : FileImportErrorCode.unknown,
        errorMessage: msg,
      );
    }
  }

  /// 字节内容导入（用于测试，跳过文件选择器）。[bytes] 为原始字节。
  Future<FileImportResult> importBytes(
    List<int> bytes,
    String originalFileName, {
    void Function(ImportProgress)? onProgress,
    bool forceImport = false,
  }) async {
    final dir = Directory.systemTemp;
    // 用唯一子目录隔离，文件名保持原始 originalFileName，
    // 以便 importFile 能正确从文件名提取书名（不受影响）。
    final tmpDir = Directory(
      p.join(dir.path, 'import_${DateTime.now().microsecondsSinceEpoch}'),
    );
    await tmpDir.create(recursive: true);
    final tmp = File(p.join(tmpDir.path, originalFileName));
    await tmp.writeAsBytes(bytes, flush: true);
    final result = await importFile(
      tmp,
      onProgress: onProgress,
      forceImport: forceImport,
    );
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    return result;
  }

  Future<String?> _checkDuplicate(
    File sourceFile,
    int fileSize,
    BookFileType fileType,
  ) async {
    final repo = BookRepository.instance;
    final books = await repo.loadAll();
    String? sha;
    try {
      sha = await FileHashService.fileSha256(sourceFile);
    } catch (_) {
      sha = null;
    }
    final baseName = p.basename(sourceFile.path).toLowerCase();
    for (final b in books) {
      if (b.fileType != fileType) continue;
      if (b.fileSize == fileSize &&
          b.originalFileName.toLowerCase() == baseName) {
        return b.id;
      }
      if (sha != null && b.originalPath.contains(sha)) {
        // originalPath 不含 hash，这里仅作大小+名称判断
      }
    }
    // 在 original 文件上比对 hash
    if (sha != null) {
      for (final b in books) {
        final orig = File(b.originalPath);
        if (await orig.exists()) {
          try {
            final otherHash = await FileHashService.fileSha256(orig);
            if (otherHash == sha) return b.id;
          } catch (_) {}
        }
      }
    }
    return null;
  }

  String _titleFromFileName(String fileName) {
    final base = p.basenameWithoutExtension(fileName);
    return base.isEmpty ? '未命名书籍' : base;
  }

  String _formatLimit(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}
