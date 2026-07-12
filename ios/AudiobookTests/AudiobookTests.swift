import XCTest
@testable import Audiobook

final class AudiobookTests: XCTestCase {
  func testChapterParserFindsChineseChapters() {
    let chapters = ChapterParser.parse("第一章 开始\n正文\n第二章 后续\n正文")
    XCTAssertEqual(chapters.count, 2)
    XCTAssertEqual(chapters[1].title, "第二章 后续")
  }

  func testImportTextParsesUtf8Content() throws {
    let text = "第一章 风起\n这是正文内容。\n第二章 云涌\n更多内容。"
    let url = makeTempFile(named: "测试小说.txt", content: Data(text.utf8))
    let result = try BookImporter.importResult(.success(url))
    XCTAssertEqual(result.title, "测试小说")
    XCTAssertEqual(result.format, "txt")
    XCTAssertTrue(result.content.contains("第一章 风起"))
    XCTAssertTrue(result.content.contains("更多内容。"))
  }

  func testImportChineseEpubParsesAndDetectsChapters() throws {
    let url = makeEpubFile(named: "demo.epub",
                           title: "演示小说",
                           chapters: [("第一章 风起", "这是第一章的正文。"),
                                      ("第二章 云涌", "这是第二章的正文。")])
    let result = try BookImporter.importResult(.success(url))
    XCTAssertEqual(result.format, "epub")
    XCTAssertEqual(result.title, "演示小说")
    XCTAssertTrue(result.content.contains("第一章 风起"))
    XCTAssertTrue(result.content.contains("这是第一章的正文。"))
    XCTAssertTrue(result.content.contains("第二章 云涌"))
    let chapters = ChapterParser.parse(result.content)
    XCTAssertGreaterThanOrEqual(chapters.count, 2)
  }

  func testImportUnsupportedFormatThrows() {
    let url = makeTempFile(named: "note.pdf", content: Data("x".utf8))
    XCTAssertThrowsError(try BookImporter.importResult(.success(url))) { error in
      guard case ImportError.unsupported = error else {
        XCTFail("应为 unsupported 错误，实际 \(error)")
        return
      }
    }
  }

  // MARK: - 测试辅助

  private func makeTempFile(named name: String, content: Data) -> URL {
    let dir = FileManager.default.temporaryDirectory
    let url = dir.appendingPathComponent(name)
    try? FileManager.default.removeItem(at: url)
    try! content.write(to: url)
    return url
  }

  /// 用 zlib 兼容的 zip(store) 造一个最小的真实 EPUB，无需系统工具。
  private func makeEpubFile(named name: String, title: String, chapters: [(String, String)]) -> URL {
    var htmlParts: [String] = []
    for entry in chapters {
      let cht = entry.0
      let body = entry.1
      let html = "<html><head><title>" + cht + "</title></head><body><h1>"
        + cht + "</h1><p>" + body + "</p></body></html>"
      htmlParts.append(html)
    }
    let container = "<container><rootfiles><rootfile full-path=\"OEBPS/content.opub\" media-type=\"application/oebps-package+xml\"/></rootfiles></container>"
    var manifest = ""
    var spine = ""
    for (i, entry) in chapters.enumerated() {
      let id = "c\(i + 1)"
      manifest += "<item id=\"" + id + "\" href=\"" + id + ".xhtml\" media-type=\"application/xhtml+xml\" title=\"" + entry.0 + "\"/>"
      spine += "<itemref idref=\"" + id + "\"/>"
    }
    let opf = "<?xml version=\"1.0\"?><package xmlns=\"\"><metadata><title>"
      + title + "</title></metadata><manifest>" + manifest
      + "</manifest><spine>" + spine + "</spine></package>"
    var entries: [(String, Data)] = [
      ("META-INF/container.xml", Data(container.utf8)),
      ("OEBPS/content.opub", Data(opf.utf8)),
    ]
    for (i, html) in htmlParts.enumerated() {
      entries.append(("OEBPS/c\(i + 1).xhtml", Data(html.utf8)))
    }
    let zip = makeZip(entries: entries)
    return makeTempFile(named: name, content: zip)
  }

  /// 最小 zip 写入（store 模式）。
  private func makeZip(entries: [(String, Data)]) -> Data {
    var out = Data()
    var central = Data()
    var offset = 0
    for (name, payload) in entries {
      let nameData = Data(name.utf8)
      var local = Data()
      local.append(UInt32(0x04034b50).littleEndianData)
      local.append(UInt16(20).littleEndianData)
      local.append(UInt16(0).littleEndianData)
      local.append(UInt16(0).littleEndianData)
      local.append(UInt16(0).littleEndianData)
      local.append(UInt16(0).littleEndianData)
      local.append(UInt32(crc32(payload)).littleEndianData)
      local.append(UInt32(payload.count).littleEndianData)
      local.append(UInt32(payload.count).littleEndianData)
      local.append(UInt16(nameData.count).littleEndianData)
      local.append(UInt16(0).littleEndianData)
      local.append(nameData)
      local.append(payload)
      out.append(local)

      var cen = Data()
      cen.append(UInt32(0x02014b50).littleEndianData)
      cen.append(UInt16(20).littleEndianData)
      cen.append(UInt16(20).littleEndianData)
      cen.append(UInt16(0).littleEndianData)
      cen.append(UInt16(0).littleEndianData)
      cen.append(UInt16(0).littleEndianData)
      cen.append(UInt16(0).littleEndianData)
      cen.append(UInt32(crc32(payload)).littleEndianData)
      cen.append(UInt32(payload.count).littleEndianData)
      cen.append(UInt32(payload.count).littleEndianData)
      cen.append(UInt16(nameData.count).littleEndianData)
      cen.append(UInt16(0).littleEndianData)
      cen.append(UInt16(0).littleEndianData)
      cen.append(UInt16(0).littleEndianData)
      cen.append(UInt16(0).littleEndianData)
      cen.append(UInt32(0).littleEndianData)
      cen.append(UInt32(offset).littleEndianData)
      cen.append(nameData)
      central.append(cen)
      offset += local.count
    }
    var eocd = Data()
    eocd.append(UInt32(0x06054b50).littleEndianData)
    eocd.append(UInt16(0).littleEndianData)
    eocd.append(UInt16(0).littleEndianData)
    eocd.append(UInt16(entries.count).littleEndianData)
    eocd.append(UInt16(entries.count).littleEndianData)
    eocd.append(UInt32(central.count).littleEndianData)
    eocd.append(UInt32(offset).littleEndianData)
    eocd.append(UInt16(0).littleEndianData)
    out.append(central)
    out.append(eocd)
    return out
  }

  private func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xffffffff
    for b in data {
      crc ^= UInt32(b)
      for _ in 0..<8 {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1
      }
    }
    return crc ^ 0xffffffff
  }
}

private extension FixedWidthInteger {
  var littleEndianData: Data {
    var v = self.littleEndian
    return Data(bytes: &v, count: MemoryLayout.size(ofValue: v))
  }
}
