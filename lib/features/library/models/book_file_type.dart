/// 书籍文件类型
enum BookFileType {
  txt,
  epub,
  pdf,
  docx;

  /// 文件扩展名（不含点）
  String get extension {
    switch (this) {
      case BookFileType.txt:
        return 'txt';
      case BookFileType.epub:
        return 'epub';
      case BookFileType.pdf:
        return 'pdf';
      case BookFileType.docx:
        return 'docx';
    }
  }

  /// 中文显示名
  String get label {
    switch (this) {
      case BookFileType.txt:
        return 'TXT';
      case BookFileType.epub:
        return 'EPUB';
      case BookFileType.pdf:
        return 'PDF';
      case BookFileType.docx:
        return 'DOCX';
    }
  }

  /// 根据扩展名解析，未知返回 null
  static BookFileType? fromExtension(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    for (final t in BookFileType.values) {
      if (t.extension == e) return t;
    }
    return null;
  }
}
