library;

import 'reader_document.dart';
import 'reader_layout.dart';
import 'reader_page_model.dart';
import 'reader_position.dart';
import 'chapter_parser.dart';
import 'chapter_cache.dart';
import 'page_cache.dart';
import 'text_paginator.dart';

/// 阅读控制器：按需加载章节、维护三章缓存、提供翻页与偏移定位。
///
/// 性能架构（参考 legado-E）：
///  - 打开书籍 -> 解析章节索引 -> 仅分页当前章 -> 缓存 prev/cur/next 三章；
///  - 翻页跨章时后台预加载相邻章，远离当前位置的缓存及时释放；
///  - 不对全书一次性分页，也不一次构建所有 Widget。
///
/// 为 Kokoro 边读边播预留：
///  - [currentChapterIndex] / [currentParagraphIndex] / [currentSentence] /
///    [currentCharacterOffset] 可供 TTS 高亮当前句、自动滚动、按字符同步。
class ReaderController {
  final String fullText;
  final ReaderLayout layout;
  final ChapterList chapters;
  final ChapterCache _cache = ChapterCache();
  final PageCache _pageCache = PageCache();

  int _chapterIndex;
  int _pageIndex = 0;
  final int totalCharacters;

  ReaderController._({
    required this.fullText,
    required this.layout,
    required this.chapters,
    required this._chapterIndex,
    required int chapterOffset,
    required this.totalCharacters,
  }) {
    _paginateAround(_chapterIndex);
    _pageIndex = _cache.current == null
        ? 0
        : _cache.current!.pageIndexAtChapterOffset(chapterOffset);
  }

  /// 构造并定位到 [globalOffset]（全书字符偏移）。
  factory ReaderController.load({
    required String fullText,
    required ReaderLayout layout,
    int globalOffset = 0,
  }) {
    // 统一先规整全文（首行缩进/换行归一），使章节偏移与分页偏移同源
    final normalized = ReaderDocument.fromContent(fullText).content;
    final parsed = ChapterParser.parse(normalized);
    final ci = parsed.chapterIndexAtOffset(globalOffset);
    final chOffset = parsed.offsetInChapter(ci, globalOffset);
    return ReaderController._(
      fullText: normalized,
      layout: layout,
      chapters: parsed,
      chapterIndex: ci,
      chapterOffset: chOffset,
      totalCharacters: parsed.totalCharacters,
    );
  }

  // ---- 内部分页 ----

  CachedChapter _paginateChapter(int index) {
    final sig = LayoutSignature(
      fontSize: layout.fontSize,
      lineHeight: layout.lineHeight,
      paragraphSpacing: layout.paragraphSpacing,
      horizontalMargin: layout.horizontalMargin,
      contentWidth: layout.contentWidth,
      contentHeight: layout.contentHeight,
      fontFamily: layout.fontFamily ?? '',
      fontWeightIndex: layout.fontWeight.value,
    );
    final ch = chapters.chapters[index];
    // PageCache 仅缓存章内局部偏移 pages；全局偏移在输出时统一加一次
    final localPages =
        _pageCache.get(index, sig) ??
        TextPaginator(
          ReaderDocument(
            content: fullText.substring(ch.start, ch.end),
            paragraphs: const [],
          ),
          layout,
        ).paginate();
    if (!_pageCache.containsKey(index, sig)) {
      _pageCache.put(index, sig, localPages);
    }
    // 页码偏移转成全书绝对偏移（text 保持章内局部内容），只加一次
    final pages = localPages
        .map(
          (p) => ReaderPageModel(
            startOffset: p.startOffset + ch.start,
            endOffset: p.endOffset + ch.start,
            text: p.text,
          ),
        )
        .toList();
    return CachedChapter(
      index: index,
      title: ch.title,
      pages: pages,
      startOffset: ch.start,
      endOffset: ch.end,
    );
  }

  void _paginateAround(int center) {
    final prevC = (center - 1 >= 0) ? _paginateChapter(center - 1) : null;
    final curC = _paginateChapter(center);
    final nextC = (center + 1 < chapters.chapters.length)
        ? _paginateChapter(center + 1)
        : null;
    _cache.update(prevChapter: prevC, currentChapter: curC, nextChapter: nextC);
  }

  // ---- 对外只读 ----

  int get chapterIndex => _chapterIndex;

  /// 当前缓存章（开发期可用于断言非空）。
  CachedChapter? get currentChapter => _cache.current;
  int get chapterCount => chapters.chapters.length;
  int get pageIndex => _pageIndex;
  int get pageCount => _cache.currentPageCount;

  /// 当前章与相邻章的全部页（连续滚动模式用）。
  List<ReaderPageModel> get currentChapterPagesWithNeighbors {
    final out = <ReaderPageModel>[];
    if (_cache.prev != null) out.addAll(_cache.prev!.pages);
    if (_cache.current != null) out.addAll(_cache.current!.pages);
    if (_cache.next != null) out.addAll(_cache.next!.pages);
    if (out.isEmpty) out.add(currentPage);
    return out;
  }

  ReaderPageModel get currentPage {
    final c = _cache.current;
    if (c == null || c.pages.isEmpty) {
      // 第三阶段：禁止用空页兜底掩盖错误。当前章未分页属于非法状态，
      // 调用方应在 ReaderPage 加载守卫（_loading / _controller==null）下等待就绪，
      // 而非渲染空白页。
      throw StateError('currentPage called before chapter paginated');
    }
    return c.pages[_pageIndex.clamp(0, c.pages.length - 1)];
  }

  int get currentCharacterOffset => currentPage.startOffset;

  /// 上一页（含跨章预取上一章末页）；首章首页返回 null。
  ReaderPageModel? get previousPage {
    if (_pageIndex > 0) {
      final c = _cache.current;
      return c == null ? null : c.pages[_pageIndex - 1];
    }
    if (_chapterIndex > 0) {
      final prevC = _paginateChapter(_chapterIndex - 1);
      return prevC.pages.isNotEmpty ? prevC.pages.last : null;
    }
    return null;
  }

  /// 下一页（含跨章预取下一章首页）；末章末页返回 null。
  ReaderPageModel? get nextPage {
    final c = _cache.current;
    if (c != null && _pageIndex < c.pages.length - 1) {
      return c.pages[_pageIndex + 1];
    }
    if (_chapterIndex < chapters.chapters.length - 1) {
      final nextC = _paginateChapter(_chapterIndex + 1);
      return nextC.pages.isNotEmpty ? nextC.pages.first : null;
    }
    return null;
  }

  /// 三章页块（prev/cur/next），供连续滚动模式拼接。
  ({
    List<ReaderPageModel>? prev,
    List<ReaderPageModel> cur,
    List<ReaderPageModel>? next,
  })
  get threeChapterBlocks {
    final cur = _cache.current?.pages ?? const <ReaderPageModel>[];
    List<ReaderPageModel>? prev;
    List<ReaderPageModel>? next;
    if (_chapterIndex > 0) {
      final prevC = _paginateChapter(_chapterIndex - 1);
      prev = prevC.pages;
    }
    if (_chapterIndex < chapters.chapters.length - 1) {
      final nextC = _paginateChapter(_chapterIndex + 1);
      next = nextC.pages;
    }
    return (prev: prev, cur: cur, next: next);
  }

  String get currentChapterTitle =>
      _cache.current?.title ?? chapters.chapters.firstOrNull?.title ?? '';

  ReaderPosition get position {
    return ReaderPosition.fromOffset(
      characterOffset: currentCharacterOffset,
      totalCharacters: totalCharacters,
      chapterIndex: _chapterIndex,
      pageIndex: _pageIndex,
    );
  }

  // ---- 翻页 ----

  bool get canNext {
    final c = _cache.current;
    if (c == null) return false;
    if (_pageIndex < c.pages.length - 1) return true;
    return _chapterIndex < chapters.chapters.length - 1;
  }

  bool get canPrev {
    if (_pageIndex > 0) return true;
    return _chapterIndex > 0;
  }

  bool get hasNext => canNext;
  bool get hasPrev => canPrev;

  /// 预览下一页（不移动，可能跨章）。
  ReaderPageModel peekNext() => nextPage ?? currentPage;

  /// 预览上一页（不移动，可能跨章）。
  ReaderPageModel peekPrev() => previousPage ?? currentPage;

  /// 翻到下一页（含跨章）。返回 false 表示已到末章末页。
  Future<bool> moveNext() async {
    final c = _cache.current;
    if (c != null && _pageIndex < c.pages.length - 1) {
      _pageIndex++;
      return true;
    }
    if (_chapterIndex < chapters.chapters.length - 1) {
      _chapterIndex++;
      _paginateAround(_chapterIndex);
      _pageIndex = 0;
      return true;
    }
    return false;
  }

  /// 翻到上一页（含跨章）。返回 false 表示已到首章首页。
  Future<bool> movePrevious() async {
    if (_pageIndex > 0) {
      _pageIndex--;
      return true;
    }
    if (_chapterIndex > 0) {
      _chapterIndex--;
      _paginateAround(_chapterIndex);
      _pageIndex = (_cache.current?.pages.length ?? 1) - 1;
      return true;
    }
    return false;
  }

  /// 跳到下一章第一页。
  Future<bool> moveToNextChapter() async {
    if (_chapterIndex < chapters.chapters.length - 1) {
      _chapterIndex++;
      _paginateAround(_chapterIndex);
      _pageIndex = 0;
      return true;
    }
    return false;
  }

  /// 跳到上一章最后一页。
  Future<bool> moveToPreviousChapter() async {
    if (_chapterIndex > 0) {
      _chapterIndex--;
      _paginateAround(_chapterIndex);
      _pageIndex = (_cache.current?.pages.length ?? 1) - 1;
      return true;
    }
    return false;
  }

  /// 跳转到指定章的指定页（PageView 当前页）。
  void goToChapterPage(int chapterIndex, int pageIndex) {
    if (chapterIndex != _chapterIndex) {
      _chapterIndex = chapterIndex;
      _paginateAround(_chapterIndex);
    }
    final c = _cache.current;
    _pageIndex = c == null ? 0 : pageIndex.clamp(0, c.pageSize - 1);
  }

  /// 取指定章的指定页（用于 PageView 构建独立页）。
  ReaderPageModel pageAtChapterPage(int chapterIndex, int pageIndex) {
    if (chapterIndex != _chapterIndex) {
      _chapterIndex = chapterIndex;
      _paginateAround(_chapterIndex);
    }
    final c = _cache.current;
    if (c == null || c.pages.isEmpty) {
      // 第三阶段：同上，禁止空页兜底。
      throw StateError('pageAtChapterPage called before chapter paginated');
    }
    return c.pages[pageIndex.clamp(0, c.pages.length - 1)];
  }

  void goToOffset(int offset) {
    final ci = chapters.chapterIndexAtOffset(offset);
    final chOffset = chapters.offsetInChapter(ci, offset);
    if (ci != _chapterIndex) {
      _chapterIndex = ci;
      _paginateAround(_chapterIndex);
    }
    final c = _cache.current;
    _pageIndex = c == null
        ? 0
        : c.pageIndexAtChapterOffset(chOffset).clamp(0, c.pageSize - 1);
  }

  void repaginate(ReaderLayout newLayout) {
    final anchor = currentCharacterOffset;
    _pageCache.clear();
    _paginateAround(_chapterIndex);
    goToOffset(anchor);
  }

  void dispose() {
    _cache.clear();
    _pageCache.clear();
  }

  // ---- Kokoro 预留 ----

  String get currentText => currentPage.text;

  String get currentSentence {
    final t = currentText;
    if (t.isEmpty) return '';
    final sentences = t.split(RegExp(r'(?<=[。！？\n])'));
    return sentences.firstWhere((s) => s.trim().isNotEmpty, orElse: () => t);
  }

  String get currentParagraph {
    final paras = currentText.split(RegExp(r'\n\s*\n'));
    return paras.firstWhere(
      (p) => p.trim().isNotEmpty,
      orElse: () => currentText,
    );
  }

  int get currentParagraphIndex {
    final parts = currentText.split(RegExp(r'\n\s*\n'));
    return parts.where((p) => p.trim().isNotEmpty).length - 1;
  }

  int get currentChapterIndex => _chapterIndex;

  // ---- 句子级（听书进度用）----
  List<String> get sentences {
    final t = currentText;
    if (t.isEmpty) return const [''];
    return t
        .split(RegExp(r'(?<=[。！？\n])'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  int get sentenceCount => sentences.length;

  /// 当前句子在页内的字符偏移（相对页 start），用于计算听书进度。
  int get sentenceCharOffset {
    final t = currentText;
    if (t.isEmpty) return 0;
    final parts = t.split(RegExp(r'(?<=[。！？\n])'));
    var acc = 0;
    for (final p in parts) {
      if (p.trim().isNotEmpty) return acc;
      acc += p.length;
    }
    return 0;
  }

  /// 听书进度 0..1（当前句在页内的位置占比，真实模型接入后可由 TTS 提供）。
  double get sentenceProgress {
    final total = currentPage.text.length;
    if (total <= 0) return 0.0;
    return (sentenceCharOffset / total).clamp(0.0, 1.0);
  }
}
