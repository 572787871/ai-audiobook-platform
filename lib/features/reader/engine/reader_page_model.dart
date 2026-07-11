/// 单页阅读数据。每一页都是真正独立、可单独渲染的单元。
///
/// 禁止整本 Text 裁剪、禁止两页共用一个 Text Widget、禁止 Transform 直接对全文动画。
/// 因此 [ReaderPageModel] 仅携带本页文本与字符范围，由阅读器逐页用独立 Widget 渲染。
class ReaderPageModel {
  /// 本页在全文中的起始字符偏移（含）。
  final int startOffset;

  /// 本页在全文中的结束字符偏移（不含）。
  final int endOffset;

  /// 本页纯文本（已包含段落换行与首行缩进空格，可直接渲染）。
  final String text;

  const ReaderPageModel({
    required this.startOffset,
    required this.endOffset,
    required this.text,
  });

  int get length => endOffset - startOffset;

  @override
  bool operator ==(Object other) =>
      other is ReaderPageModel &&
      other.startOffset == startOffset &&
      other.endOffset == endOffset &&
      other.text == text;

  @override
  int get hashCode => startOffset.hashCode ^ endOffset.hashCode ^ text.hashCode;
}
