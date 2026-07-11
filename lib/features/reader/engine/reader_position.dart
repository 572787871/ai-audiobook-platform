/// 阅读位置：以字符偏移（characterOffset）为准，不依赖页码。
///
/// 恢复阅读时根据 [characterOffset] 定位到对应页，避免"根据 pageIndex 恢复"在
/// 字号/行距/边距/横竖屏变化后错位的问题。
class ReaderPosition {
  /// 章节索引（单文件 TXT 通常为 0；多章节解析后用于跳转）。
  final int chapterIndex;

  /// 正文中的字符偏移（从 0 开始），用于精确定位。
  final int characterOffset;

  /// 阅读进度（0.0 ~ 1.0），由 characterOffset / totalCharacters 计算。
  final double readingProgress;

  /// 累计阅读时长（秒）。
  final int readingTimeSec;

  /// 最后阅读时间。
  final DateTime? lastReadAt;

  const ReaderPosition({
    this.chapterIndex = 0,
    this.characterOffset = 0,
    this.readingProgress = 0.0,
    this.readingTimeSec = 0,
    this.lastReadAt,
  });

  ReaderPosition copyWith({
    int? chapterIndex,
    int? characterOffset,
    double? readingProgress,
    int? readingTimeSec,
    DateTime? lastReadAt,
  }) =>
      ReaderPosition(
        chapterIndex: chapterIndex ?? this.chapterIndex,
        characterOffset: characterOffset ?? this.characterOffset,
        readingProgress: readingProgress ?? this.readingProgress,
        readingTimeSec: readingTimeSec ?? this.readingTimeSec,
        lastReadAt: lastReadAt ?? this.lastReadAt,
      );

  /// 由字符偏移与全文长度推导进度。
  factory ReaderPosition.fromOffset({
    required int characterOffset,
    required int totalCharacters,
    int chapterIndex = 0,
  }) {
    final progress = totalCharacters <= 0
        ? 0.0
        : (characterOffset / totalCharacters).clamp(0.0, 1.0);
    return ReaderPosition(
      chapterIndex: chapterIndex,
      characterOffset: characterOffset.clamp(0, totalCharacters),
      readingProgress: progress,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderPosition &&
      other.chapterIndex == chapterIndex &&
      other.characterOffset == characterOffset &&
      other.readingProgress == readingProgress &&
      other.readingTimeSec == readingTimeSec;

  @override
  int get hashCode =>
      chapterIndex.hashCode ^ characterOffset.hashCode ^ readingProgress.hashCode ^ readingTimeSec.hashCode;
}
