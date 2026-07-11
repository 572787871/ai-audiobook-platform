import 'book_file_type.dart';
import 'book_parse_status.dart';

/// 一本书籍的本地记录。
///
/// 所有持久化字段均为可空，避免损坏记录导致崩溃。
class Book {
  Book({
    required this.id,
    required this.title,
    this.author,
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
    this.chapterIndex = 0,
    this.pageIndex = 0,
    this.lastReadChapter,
    this.readingProgress = 0.0,
    this.readingTimeSec = 0,
    this.lastReadAt,
    required this.parseStatus,
    this.chapterCount,
    this.coverPath,
    this.streakDays = 0,
    this.lastReadDay,
    this.isListening = false,
    this.listenRate = 1.0,
    this.listenVoice,
  });

  final String id;
  final String title;
  final String? author;
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
  final int chapterIndex;
  final int pageIndex;
  final String? lastReadChapter;
  final double readingProgress;
  final int readingTimeSec;
  final DateTime? lastReadAt;
  final BookParseStatus parseStatus;
  final int? chapterCount;
  final String? coverPath;
  /// 连续阅读天数（按自然日去重，跨天清零）。
  final int streakDays;
  /// 上次阅读的自然日（YYYY-MM-DD），用于连续天数计算。
  final String? lastReadDay;
  /// 是否正在听书。
  final bool isListening;
  /// 听书语速倍率（0.5/1.0/1.5/2.0）。
  final double listenRate;
  /// 听书音色标识（预留 Kokoro voice，如 af_heart）。
  final String? listenVoice;

  Book copyWith({
    String? title,
    String? author,
    String? contentPath,
    int? fileSize,
    int? characterCount,
    String? encoding,
    DateTime? updatedAt,
    int? lastReadOffset,
    int? chapterIndex,
    int? pageIndex,
    String? lastReadChapter,
    double? readingProgress,
    int? readingTimeSec,
    DateTime? lastReadAt,
    BookParseStatus? parseStatus,
    int? chapterCount,
    String? coverPath,
    int? streakDays,
    String? lastReadDay,
    bool? isListening,
    double? listenRate,
    String? listenVoice,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
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
      chapterIndex: chapterIndex ?? this.chapterIndex,
      pageIndex: pageIndex ?? this.pageIndex,
      lastReadChapter: lastReadChapter ?? this.lastReadChapter,
      readingProgress: readingProgress ?? this.readingProgress,
      readingTimeSec: readingTimeSec ?? this.readingTimeSec,
      parseStatus: parseStatus ?? this.parseStatus,
      chapterCount: chapterCount ?? this.chapterCount,
      coverPath: coverPath ?? this.coverPath,
      streakDays: streakDays ?? this.streakDays,
      lastReadDay: lastReadDay ?? this.lastReadDay,
      isListening: isListening ?? this.isListening,
      listenRate: listenRate ?? this.listenRate,
      listenVoice: listenVoice ?? this.listenVoice,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
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
        'chapterIndex': chapterIndex,
        'pageIndex': pageIndex,
        'lastReadChapter': lastReadChapter,
        'readingProgress': readingProgress,
        'readingTimeSec': readingTimeSec,
        'parseStatus': parseStatus.name,
        'chapterCount': chapterCount,
        'coverPath': coverPath,
        'streakDays': streakDays,
        'lastReadDay': lastReadDay,
        'isListening': isListening,
        'listenRate': listenRate,
        'listenVoice': listenVoice,
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
        author: json['author'] as String?,
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
        chapterIndex: (json['chapterIndex'] as int?) ?? 0,
        lastReadChapter: json['lastReadChapter'] as String?,
        readingProgress: (json['readingProgress'] as double?) ?? 0.0,
        readingTimeSec: (json['readingTimeSec'] as int?) ?? 0,
        parseStatus: parseStatus,
        chapterCount: json['chapterCount'] as int?,
        coverPath: json['coverPath'] as String?,
        streakDays: (json['streakDays'] as int?) ?? 0,
        lastReadDay: json['lastReadDay'] as String?,
        isListening: (json['isListening'] as bool?) ?? false,
        listenRate: (json['listenRate'] as num?)?.toDouble() ?? 1.0,
        listenVoice: json['listenVoice'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// 标记一次“今天已阅读”，自动维护连续天数（按自然日去重）。
  /// 同一天多次调用不会重复累加；跨天连续 +1，断签重置为 1。
  Book withReadingToday(DateTime now) {
    final day =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (lastReadDay == day) {
      return copyWith(updatedAt: now);
    }
    int streak = 1;
    if (lastReadDay != null) {
      try {
        final prev = DateTime.parse(lastReadDay!);
        final prevDay = DateTime(prev.year, prev.month, prev.day);
        final today = DateTime(now.year, now.month, now.day);
        final diff = today.difference(prevDay).inDays;
        if (diff == 1) streak = streakDays + 1;
      } catch (_) {
        streak = 1;
      }
    }
    return copyWith(
      lastReadDay: day,
      streakDays: streak,
      updatedAt: now,
    );
  }
}
