/// 解析状态
enum BookParseStatus {
  /// 已可阅读（TXT 导入成功）
  ready,

  /// 等待解析（EPUB / PDF / DOCX 暂未解析）
  pending,

  /// 解析失败
  failed,
}

extension BookParseStatusX on BookParseStatus {
  String get label {
    switch (this) {
      case BookParseStatus.ready:
        return '已导入';
      case BookParseStatus.pending:
        return '等待解析';
      case BookParseStatus.failed:
        return '解析失败';
    }
  }
}
