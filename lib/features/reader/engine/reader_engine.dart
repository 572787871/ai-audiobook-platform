import 'reader_document.dart';
import 'reader_layout.dart';
import 'reader_page_model.dart';
import 'reader_position.dart';
import 'text_paginator.dart';

/// 阅读引擎：将正文 + 排版参数转换为独立的页列表。
///
/// 不依赖任何 UI，可独立测试。编码（UTF-8/GBK/GB18030/BIG5/UTF16）已在导入层
/// 解码为 String，这里只做结构化与分页。
class ReaderEngine {
  final ReaderDocument document;
  final ReaderLayout layout;

  const ReaderEngine(this.document, this.layout);

  /// 执行分页，返回真正独立的页列表。
  List<ReaderPageModel> paginate() => TextPaginator(document, layout).paginate();

  /// 根据字符偏移定位到页索引（二分查找）。
  int pageIndexForOffset(int offset, List<ReaderPageModel> pages) {
    if (pages.isEmpty) return 0;
    var lo = 0, hi = pages.length - 1, ans = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (pages[mid].startOffset <= offset) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  /// 由字符偏移推导 [ReaderPosition]（进度 = offset / total）。
  ReaderPosition positionForOffset(int offset) =>
      ReaderPosition.fromOffset(
        characterOffset: offset,
        totalCharacters: document.totalCharacters,
      );
}
