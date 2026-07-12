/// 分页结果缓存（参考 legado-E 分页缓存思想，Dart 独立重写）。
///
/// 按 (章节索引 + 排版签名) 缓存已分页的 [ReaderPageModel] 列表，
/// 字号/行距/边距/屏幕尺寸变化导致排版签名改变时自动失效。
/// 配合 [ChapterCache] 三段缓存，避免重复分页与全书一次性构建 Widget。
library;

import 'reader_page_model.dart';

/// 排版签名：用于在布局参数变化时判断是否需重分页。
class LayoutSignature {
  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final double horizontalMargin;
  final double contentWidth;
  final double contentHeight;
  final String fontFamily;
  final int fontWeightIndex;

  const LayoutSignature({
    required this.fontSize,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.horizontalMargin,
    required this.contentWidth,
    required this.contentHeight,
    required this.fontFamily,
    required this.fontWeightIndex,
  });

  @override
  bool operator ==(Object other) =>
      other is LayoutSignature &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.paragraphSpacing == paragraphSpacing &&
      other.horizontalMargin == horizontalMargin &&
      other.contentWidth == contentWidth &&
      other.contentHeight == contentHeight &&
      other.fontFamily == fontFamily &&
      other.fontWeightIndex == fontWeightIndex;

  @override
  int get hashCode => Object.hash(
    fontSize,
    lineHeight,
    paragraphSpacing,
    horizontalMargin,
    contentWidth,
    contentHeight,
    fontFamily,
    fontWeightIndex,
  );
}

class _Entry {
  final LayoutSignature signature;
  final List<ReaderPageModel> pages;
  _Entry(this.signature, this.pages);
}

class PageCache {
  final int maxEntries;
  final Map<int, _Entry> _map = {};

  PageCache({this.maxEntries = 6});

  /// 是否已缓存（签名匹配）。
  bool containsKey(int chapterIndex, LayoutSignature sig) {
    final e = _map[chapterIndex];
    if (e == null) return false;
    if (e.signature != sig) {
      _map.remove(chapterIndex);
      return false;
    }
    return true;
  }

  /// 取缓存分页；签名不匹配返回 null。
  List<ReaderPageModel>? get(int chapterIndex, LayoutSignature sig) {
    final e = _map[chapterIndex];
    if (e == null) return null;
    if (e.signature != sig) {
      _map.remove(chapterIndex);
      return null;
    }
    // LRU：命中后移到末尾
    _map.remove(chapterIndex);
    _map[chapterIndex] = e;
    return e.pages;
  }

  void put(int chapterIndex, LayoutSignature sig, List<ReaderPageModel> pages) {
    _map[chapterIndex] = _Entry(sig, pages);
    while (_map.length > maxEntries) {
      _map.remove(_map.keys.first);
    }
  }

  void clear() => _map.clear();
}
