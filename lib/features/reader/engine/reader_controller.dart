import 'reader_engine.dart';
import 'reader_page_model.dart';
import 'reader_position.dart';

/// 阅读控制器：持有分页结果，提供翻页、偏移定位、当前句/段/字符偏移查询。
///
/// 为 Kokoro 边读边播预留：
///  - [currentSentence] / [currentParagraph] / [currentCharacterOffset]
/// 可供 TTS 高亮当前句、自动滚动、按字符同步。
class ReaderController {
  final ReaderEngine engine;
  List<ReaderPageModel> _pages;
  int _pageIndex;

  ReaderController({
    required this.engine,
    List<ReaderPageModel>? pages,
    this._pageIndex = 0,
  })  : _pages = pages ?? engine.paginate();

  List<ReaderPageModel> get pages => _pages;
  int get pageIndex => _pageIndex;
  int get pageCount => _pages.length;

  ReaderPageModel get currentPage =>
      _pages.isEmpty ? const ReaderPageModel(startOffset: 0, endOffset: 0, text: '') : _pages[_pageIndex];

  /// 当前页起始字符偏移。
  int get currentCharacterOffset => currentPage.startOffset;

  /// 重新分页（字号/行距/边距/横竖屏变化后调用），并尽量保持阅读位置。
  void repaginate({int? keepOffset}) {
    final anchor = keepOffset ?? currentCharacterOffset;
    _pages = engine.paginate();
    _pageIndex = engine.pageIndexForOffset(anchor, _pages);
  }

  void goToPage(int index) {
    if (index >= 0 && index < _pages.length) _pageIndex = index;
  }

  /// 根据字符偏移定位（不依赖页码）。
  void goToOffset(int offset) {
    _pageIndex = engine.pageIndexForOffset(offset, _pages);
  }

  bool get canNext => _pageIndex < _pages.length - 1;
  bool get canPrev => _pageIndex > 0;

  void next() {
    if (canNext) _pageIndex++;
  }

  void prev() {
    if (canPrev) _pageIndex--;
  }

  ReaderPosition get position =>
      engine.positionForOffset(currentCharacterOffset);

  // ---- Kokoro 预留：句 / 段 / 字符偏移 ----

  /// 当前页文本。
  String get currentText => currentPage.text;

  /// 当前句子（以句号、叹号、问号、换行断句；简化实现，后续可接 NLP）。
  String get currentSentence {
    final t = currentText;
    if (t.isEmpty) return '';
    // 取第一段非空句
    final sentences = t.split(RegExp(r'(?<=[。！？\n])'));
    return sentences.firstWhere((s) => s.trim().isNotEmpty, orElse: () => t);
  }

  /// 当前段落（按空行分段，取第一段）。
  String get currentParagraph {
    final paras = currentText.split(RegExp(r'\n\s*\n'));
    return paras.firstWhere((p) => p.trim().isNotEmpty, orElse: () => currentText);
  }
}
