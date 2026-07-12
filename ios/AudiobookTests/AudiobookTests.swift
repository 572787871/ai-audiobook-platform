import XCTest
@testable import Audiobook

final class AudiobookTests: XCTestCase {
  func testChapterParserFindsChineseChapters() {
    let chapters = ChapterParser.parse("第一章 开始\n正文\n第二章 后续\n正文")
    XCTAssertEqual(chapters.count, 2)
    XCTAssertEqual(chapters[1].title, "第二章 后续")
  }
}
