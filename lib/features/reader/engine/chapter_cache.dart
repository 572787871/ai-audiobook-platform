/// 章节分页结果缓存（参考 legado-E CacheBook 三段缓存思想，Dart 独立重写）。
///
/// 不一次分页全书：只保留 [prev] / [current] / [next] 三章的分页结果，
/// 远离当前阅读位置的章节分页及时释放，控制内存不随翻页上涨。
/// 用于支持 50 万 / 100 万字 TXT 快速打开与稳定翻页。
library;

import 'reader_page_model.dart';

class CachedChapter {
  final int index;
  final String title;
  final List<ReaderPageModel> pages;
  final int startOffset; // 本章在全文的起始字符偏移
  final int endOffset; // 本章在全文的结束字符偏移

  const CachedChapter({
    required this.index,
    required this.title,
    required this.pages,
    required this.startOffset,
    required this.endOffset,
  });

  int get pageSize => pages.length;

  /// 本章内字符偏移 -> 页索引。
  int pageIndexAtChapterOffset(int chapterOffset) {
    int lo = 0, hi = pages.length - 1, ans = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (pages[mid].startOffset - startOffset <= chapterOffset) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }
}

class ChapterCache {
  CachedChapter? prev;
  CachedChapter? current;
  CachedChapter? next;

  ChapterCache();

  /// 设置当前章与相邻章，并自动释放远处缓存。
  void update({
    CachedChapter? prevChapter,
    required CachedChapter currentChapter,
    CachedChapter? nextChapter,
  }) {
    prev = prevChapter;
    current = currentChapter;
    next = nextChapter;
  }

  /// 当前章页总数（无则为 0）。
  int get currentPageCount => current?.pageSize ?? 0;

  /// 根据全文字符偏移定位所在缓存章；若不在三章内返回 null（需重新加载）。
  CachedChapter? chapterAtOffset(int globalOffset) {
    for (final c in [prev, current, next]) {
      if (c != null &&
          globalOffset >= c.startOffset &&
          globalOffset < c.endOffset) {
        return c;
      }
    }
    return null;
  }

  /// 释放所有缓存（切换书籍时调用）。
  void clear() {
    prev = null;
    current = null;
    next = null;
  }
}
