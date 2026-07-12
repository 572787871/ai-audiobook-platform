/// TXT 自动分章（参考 legado-E TextFile.analyze 思想，Dart 独立重写）。
library;

///
/// 不依赖 Android，使用 Dart RegExp 匹配常见章节标题格式，
/// 按匹配位置切分章节，记录每章 [ChapterInfo.start] / [ChapterInfo.end]
/// 字符偏移，供按需加载与按字符偏移定位。
///
/// 默认规则覆盖常见中文网文标题：
///   第N章 / 第N回 / 第N卷 / 楔子 / 序言 / 引子 / 番外 / 尾声
///   以及 "一、二、..." 等中文数字序号开头的行。

class ChapterInfo {
  final int index;
  final String title;
  final int start; // 章节正文起始字符偏移（含标题）
  final int end; // 章节正文结束字符偏移（不含下一章标题）
  int get length => (end - start).clamp(0, end - start);

  ChapterInfo({
    required this.index,
    required this.title,
    required this.start,
    required this.end,
  });

  @override
  String toString() => 'ChapterInfo(#$index $title [$start,$end) len=$length)';
}

/// 章节解析结果。
class ChapterList {
  final List<ChapterInfo> chapters;
  final int totalCharacters;

  ChapterList(this.chapters, this.totalCharacters);

  /// 根据全局字符偏移定位所属章节索引（二分）。
  int chapterIndexAtOffset(int offset) {
    int lo = 0, hi = chapters.length - 1, ans = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (chapters[mid].start <= offset) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  /// 章节内偏移：全局 offset - 章节 start。
  int offsetInChapter(int chapterIndex, int globalOffset) {
    if (chapterIndex < 0 || chapterIndex >= chapters.length) return 0;
    return (globalOffset - chapters[chapterIndex].start).clamp(
      0,
      chapters[chapterIndex].length,
    );
  }
}

class TxtChapterRule {
  final String pattern;
  final String replacement;
  final String? example;

  const TxtChapterRule({
    required this.pattern,
    this.replacement = '',
    this.example,
  });

  RegExp get regex => RegExp(pattern, multiLine: true);
}

/// 默认中文网文分章规则集合（按顺序尝试，命中即采用）。
const List<TxtChapterRule> defaultTxtRules = [
  TxtChapterRule(
    pattern: r'^\s*(第[零一二三四五六七八九十百千0-9]+[章回卷节部篇集][^\n]*)\s*$',
    replacement: '',
    example: '第一章 初入江湖',
  ),
  TxtChapterRule(
    pattern: r'^\s*(楔子|序言|序章|引子|前言|番外|尾声|后记|附录)[^\n]*\s*$',
    replacement: '',
    example: '楔子',
  ),
  TxtChapterRule(
    pattern: r'^\s*([一二三四五六七八九十百千]+(?:、|\.|\s))\S{0,30}$',
    replacement: '',
    example: '一、少年',
  ),
];

class ChapterParser {
  /// 解析全文为章节列表。
  ///
  /// [text] 为已解码正文（UTF-8/GBK/GB18030/BIG5/UTF16 由导入层处理为 String）。
  /// [rules] 可选自定义规则，缺省用 [defaultTxtRules]。
  /// 若没有任何规则命中，则整体作为单章（index 0）。
  static ChapterList parse(
    String text, {
    List<TxtChapterRule> rules = defaultTxtRules,
    int maxChapterLength = 200000,
  }) {
    final total = text.length;
    if (text.isEmpty) {
      return ChapterList([], 0);
    }

    RegExp? chosen;
    for (final rule in rules) {
      final re = rule.regex;
      if (re.hasMatch(text)) {
        chosen = re;
        break;
      }
    }

    if (chosen == null) {
      return ChapterList([
        ChapterInfo(index: 0, title: '正文', start: 0, end: total),
      ], total);
    }

    final matches = chosen.allMatches(text).toList();
    if (matches.isEmpty) {
      return ChapterList([
        ChapterInfo(index: 0, title: '正文', start: 0, end: total),
      ], total);
    }

    // 去重相邻匹配，过滤过长章节（超过 maxChapterLength 用前缀作为标题位置）
    final starts = <int>[];
    final titles = <String>[];
    int? lastStart;
    for (final m in matches) {
      final start = m.start;
      if (lastStart != null && start - lastStart < 8) continue; // 太近跳过
      final rawTitle = m.group(0)?.trim() ?? '';
      final title = rawTitle.isEmpty ? '正文' : rawTitle;
      starts.add(start);
      titles.add(title);
      lastStart = start;
    }

    final chapters = <ChapterInfo>[];
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final end = (i + 1 < starts.length) ? starts[i + 1] : total;
      chapters.add(
        ChapterInfo(index: i, title: titles[i], start: start, end: end),
      );
    }

    // 若首章标题不在文件最开头，补一个"正文/前言"章节
    if (chapters.isNotEmpty && chapters.first.start > 0) {
      chapters.insert(
        0,
        ChapterInfo(index: 0, title: '正文', start: 0, end: chapters.first.start),
      );
      for (var i = 1; i < chapters.length; i++) {
        chapters[i] = ChapterInfo(
          index: i,
          title: chapters[i].title,
          start: chapters[i].start,
          end: chapters[i].end,
        );
      }
    }

    return ChapterList(chapters, total);
  }
}
