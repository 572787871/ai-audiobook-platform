import '../library/models/book.dart';

/// 导入结果
class FileImportResult {
  const FileImportResult({
    required this.success,
    this.book,
    this.errorCode,
    this.errorMessage,
    this.existingBookId,
  });

  /// 是否成功
  final bool success;

  /// 成功时返回的书籍
  final Book? book;

  /// 错误码
  final FileImportErrorCode? errorCode;

  /// 错误信息（中文，可直接展示）
  final String? errorMessage;

  /// 重复时指向已存在书籍 id
  final String? existingBookId;

  bool get isDuplicate => errorCode == FileImportErrorCode.duplicate;
}

/// 导入失败原因
enum FileImportErrorCode {
  fileNotFound, // 文件不存在
  emptyFile, // 文件为空
  unsupportedExtension, // 不支持的扩展名
  tooLarge, // 超过大小限制
  duplicate, // 重复导入
  encodingFailed, // 编码识别失败
  unknown, // 未知错误
}
