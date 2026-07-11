import 'book_file_type.dart';
import 'book_parse_status.dart';

/// 一本书籍的本地记录。
///
/// 所有持久化字段均为可空，避免损坏记录导致崩溃。
class Book {
  Book({
    required this.id,
    required this.title,
    required this.originalFileName,
    required this.fileType,
    required this.originalPath,
    this.contentPath,
    required this.fileSize,
    this.characterCount,
    this.encoding,
    required this.createdAt,
    required this.updatedAt,
    this.lastReadOffset = 0,
    this.lastReadChapter,
    this.readingProgress = 0.0,
    this.readingTimeSec = 0,
    required this.parseStatus,
    this.chapterCount,
    this.coverPath,
  });

  final String id;
  final String title;
  final String originalFileName;
  final BookFileType fileType;
  final String originalPath;
  final String? contentPath;
  final int fileSize;
  final int? characterCount;
  final String? encoding;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int lastReadOffset;
  final String? lastReadChapter;
  final double readingProgress;
  final int readingTimeSec;
  final BookParseStatus parseStatus;
  final int? chapterCount;
  final String? coverPath;

  Book copyWith({
    String? title,
    String? contentPath,
    int? fileSize,
    int? characterCount,
    String? encoding,
    DateTime? updatedAt,
    int? lastReadOffset,
    String? lastReadChapter,
    double? readingProgress,
    int? readingTimeSec,
    BookParseStatus? parseStatus,
    int? chapterCount,
    String? coverPath,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      originalFileName: originalFileName,
      fileType: fileType,
      originalPath: originalPath,
      contentPath: contentPath ?? this.contentPath,
      fileSize: fileSize ?? this.fileSize,
      characterCount: characterCount ?? this.characterCount,
      encoding: encoding ?? this.encoding,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastReadOffset: lastReadOffset ?? this.lastReadOffset,
      lastReadChapter: lastReadChapter ?? this.lastReadChapter,
      readingProgress: readingProgress ?? this.readingProgress,
      readingTimeSec: readingTimeSec ?? this.readingTimeSec,
      parseStatus: parseStatus ?? this.parseStatus,
      chapterCount: chapterCount ?? this.chapterCount,
      coverPath: coverPath ?? this.coverPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'originalFileName': originalFileName,
        'fileType': fileType.name,
        'originalPath': originalPath,
        'contentPath': contentPath,
        'fileSize': fileSize,
        'characterCount': characterCount,
        'encoding': encoding,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastReadOffset': lastReadOffset,
        'lastReadChapter': lastReadChapter,
        'readingProgress': readingProgress,
        'readingTimeSec': readingTimeSec,
        'parseStatus': parseStatus.name,
        'chapterCount': chapterCount,
        'coverPath': coverPath,
      };

  /// 从 JSON 解析。任何字段缺失或类型错误都返回 null（跳过损坏记录）。
  static Book? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String?;
      final originalFileName = json['originalFileName'] as String?;
      final fileTypeStr = json['fileType'] as String?;
      final originalPath = json['originalPath'] as String?;
      final fileSize = json['fileSize'];
      final createdAt = json['createdAt'] as String?;
      final updatedAt = json['updatedAt'] as String?;
      final parseStatusStr = json['parseStatus'] as String?;
      if (id == null ||
          originalFileName == null ||
          fileTypeStr == null ||
          originalPath == null ||
          fileSize is! int ||
          createdAt == null ||
          updatedAt == null ||
          parseStatusStr == null) {
        return null;
      }
      final fileType = BookFileType.values.where((e) => e.name == fileTypeStr).firstOrNull;
      final parseStatus =
          BookParseStatus.values.where((e) => e.name == parseStatusStr).firstOrNull;
      if (fileType == null || parseStatus == null) return null;
      return Book(
        id: id,
        title: (json['title'] as String?) ?? originalFileName,
        originalFileName: originalFileName,
        fileType: fileType,
        originalPath: originalPath,
        contentPath: json['contentPath'] as String?,
        fileSize: fileSize,
        characterCount: json['characterCount'] as int?,
        encoding: json['encoding'] as String?,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
        lastReadOffset: (json['lastReadOffset'] as int?) ?? 0,
        lastReadChapter: json['lastReadChapter'] as String?,
        readingProgress: (json['readingProgress'] as double?) ?? 0.0,
        readingTimeSec: (json['readingTimeSec'] as int?) ?? 0,
        parseStatus: parseStatus,
        chapterCount: json['chapterCount'] as int?,
        coverPath: json['coverPath'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
