/// 阅读文档：对已解码为 Dart [String] 的正文做结构化规整。
///
/// 编码（UTF-8 / GBK / GB18030 / BIG5 / UTF-16）由导入层负责解码为 String，
/// 这里不处理字节；仅做段落切分、首行缩进、段落间距等排版预处理。
class ReaderDocument {
  /// 全文纯文本。
  final String content;

  /// 段落列表（已去除首尾空白，保留空行作为分隔）。
  final List<String> paragraphs;

  const ReaderDocument({
    required this.content,
    required this.paragraphs,
  });

  /// 全文长度（字符数）。
  int get totalCharacters => content.length;

  /// 由原始正文构建文档。
  ///
  /// [firstLineIndent]：每段首行缩进空格数（中文排版通常为 2）。
  /// [paragraphSpacing]：段落之间额外空行数（仅影响分页时的视觉间距，此处保留语义）。
  factory ReaderDocument.fromContent(
    String rawContent, {
    int firstLineIndent = 2,
    int paragraphSpacing = 1,
  }) {
    final normalized = rawContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawParas = normalized.split('\n');
    final paragraphs = <String>[];
    for (var i = 0; i < rawParas.length; i++) {
      final p = rawParas[i].trim();
      if (p.isEmpty) {
        // 空行：作为段落分隔计入（若前后已有内容）
        if (paragraphs.isNotEmpty && paragraphs.last.isNotEmpty) {
          paragraphs.add('');
        }
        continue;
      }
      final indent = (paragraphs.isEmpty || paragraphs.last.isEmpty)
          ? ' ' * firstLineIndent
          : '';
      paragraphs.add('$indent$p');
    }
    // 重建带换行的正文（段落间按 paragraphSpacing 补空行）
    final text = paragraphs.join('\n' * (paragraphSpacing + 1));
    return ReaderDocument(content: text, paragraphs: paragraphs);
  }
}
