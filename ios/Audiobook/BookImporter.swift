import Foundation
import UniformTypeIdentifiers
import CoreFoundation

extension String.Encoding {
  /// GB18030 兼容 GBK / GB2312，覆盖绝大多数中文 Windows 导出的 txt。
  static let gb18030 = String.Encoding(
    rawValue: CFStringConvertEncodingToNSStringEncoding(
      CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
    )
  )
}

enum BookImporter {
  static func importResult(_ result: Result<URL, Error>) throws -> (title: String, content: String, format: String) {
    let url = try result.get()
    let ext = url.pathExtension.lowercased()
    switch ext {
    case "txt": return try importText(url: url)
    case "epub": return try importEpub(url: url)
    default: throw ImportError.unsupported(ext)
    }
  }

  private static func importText(url: URL) throws -> (title: String, content: String, format: String) {
    let data = try Data(contentsOf: url)
    guard !data.isEmpty else { throw ImportError.encoding }
    // 优先用系统编码嗅探（能区分 UTF-8 / UTF-16 / UTF-32 以及带 BOM 的情况），
    // 再按常见编码依次尝试，最大限度兼容中文 txt。
    let text = decodeText(data)
    guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ImportError.encoding
    }
    return (title: url.deletingPathExtension().lastPathComponent, content: text, format: "txt")
  }

  /// 按「系统嗅探 → 常见编码依次尝试」的顺序解码，兜底 latin1 防止乱码后空内容。
  private static func decodeText(_ data: Data) -> String? {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("txt")
    try? data.write(to: tmp)
    defer { try? FileManager.default.removeItem(at: tmp) }
    var detected = String.Encoding.utf8
    if let s = try? String(contentsOf: tmp, usedEncoding: &detected), !s.isEmpty { return s }
    let candidates: [String.Encoding] = [
      .utf8,
      .utf16,
      .utf16LittleEndian,
      .utf16BigEndian,
      .utf32,
      .utf32LittleEndian,
      .utf32BigEndian,
      .gb18030,
      .isoLatin1
    ]
    for enc in candidates {
      if let s = String(data: data, encoding: enc), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return s
      }
    }
    return nil
  }

  static func importEpub(url: URL) throws -> (title: String, content: String, format: String) {
    let entries = try ZipArchive.entries(at: url)
    guard !entries.isEmpty else { throw ImportError.epubCorrupt }
    let containerData = try ZipArchive.data(for: "META-INF/container.xml", in: entries, at: url)
    let opfPath = try EpubManifest.opfPath(from: containerData)
    let opfData = try ZipArchive.data(for: opfPath, in: entries, at: url)
    let meta = try EpubManifest.parseOPF(opfData, opfPath: opfPath)
    var parts: [(title: String, text: String)] = []
    for href in meta.spine {
      guard let data = try? ZipArchive.data(for: href, in: entries, at: url) else { continue }
      guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16),
            !html.isEmpty else { continue }
      let title = meta.titles[href] ?? meta.fallbackTitle
      parts.append((title: title, text: EpubText.strip(html: html)))
    }
    let content = parts.map { "\($0.title)\n\n\($0.text)" }.joined(separator: "\n\n")
    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ImportError.epubCorrupt
    }
    let title = meta.bookTitle.isEmpty ? url.deletingPathExtension().lastPathComponent : meta.bookTitle
    return (title: title, content: content, format: "epub")
  }
}

enum ImportError: LocalizedError {
  case accessDenied, encoding, unsupported(String), epubCorrupt
  var errorDescription: String? {
    switch self {
    case .accessDenied: "无法读取所选文件"
    case .encoding: "无法识别文本编码或文件为空"
    case let .unsupported(ext): "暂不支持 .\(ext) 格式，请导入 TXT 或 EPUB"
    case .epubCorrupt: "EPUB 解析失败，文件可能已损坏"
    }
  }
}

struct ZipArchive {
  static func entries(at url: URL) throws -> [ZipEntry] {
    let data = try Data(contentsOf: url)
    guard data.count >= 22 else { throw ImportError.epubCorrupt }
    let eocd = try findEOCD(data)
    let total = Int(eocd.count)
    guard total > 0 else { throw ImportError.epubCorrupt }
    var entries: [ZipEntry] = []
    var offset = Int(eocd.centralOffset)
    for _ in 0..<total {
      guard offset + 46 <= data.count else { break }
      guard data.uint32(at: offset) == 0x02014b50 else { break }
      let method = Int(data.uint16(at: offset + 10))
      let compSize = Int(data.uint32(at: offset + 20))
      let uncompSize = Int(data.uint32(at: offset + 24))
      let nameLen = Int(data.uint16(at: offset + 28))
      let extraLen = Int(data.uint16(at: offset + 30))
      let commentLen = Int(data.uint16(at: offset + 32))
      let localOffset = Int(data.uint32(at: offset + 42))
      let nameStart = offset + 46
      guard nameStart + nameLen <= data.count else { break }
      let name = String(data: data.subdata(in: nameStart..<(nameStart + nameLen)), encoding: .utf8) ?? ""
      entries.append(ZipEntry(name: name, method: method, compSize: compSize,
                              uncompSize: uncompSize, localHeaderOffset: localOffset))
      offset = nameStart + nameLen + extraLen + commentLen
    }
    return entries
  }

  static func data(for name: String, in entries: [ZipEntry], at url: URL) throws -> Data {
    let keys = [name, name.hasPrefix("/") ? String(name.dropFirst()) : "/\(name)"]
    guard let entry = entries.first(where: { keys.contains($0.name) }) else {
      throw ImportError.epubCorrupt
    }
    let data = try Data(contentsOf: url)
    let base = entry.localHeaderOffset
    guard base + 30 <= data.count else { throw ImportError.epubCorrupt }
    let nameLen = Int(data.uint16(at: base + 26))
    let extraLen = Int(data.uint16(at: base + 28))
    let bodyStart = base + 30 + nameLen + extraLen
    let body = data.subdata(in: bodyStart..<min(bodyStart + entry.compSize, data.count))
    switch entry.method {
    case 0: return body
    case 8:
      guard let out = Inflater.inflate(body) else { throw ImportError.epubCorrupt }
      return out
    default: throw ImportError.epubCorrupt
    }
  }

  private static func findEOCD(_ data: Data) throws -> (count: UInt16, centralOffset: UInt32) {
    for i in stride(from: data.count - 22, through: 0, by: -1) {
      if data.uint32(at: i) == 0x06054b50 {
        return (data.uint16(at: i + 10), data.uint32(at: i + 16))
      }
    }
    throw ImportError.epubCorrupt
  }
}

struct ZipEntry {
  let name: String
  let method: Int
  let compSize: Int
  let uncompSize: Int
  let localHeaderOffset: Int
}

struct EpubManifest {
  struct Meta {
    var bookTitle: String = ""
    var spine: [String] = []
    var titles: [String: String] = [:]
    var fallbackTitle: String = "正文"
  }

  static func opfPath(from containerXML: Data) throws -> String {
    guard let xml = String(data: containerXML, encoding: .utf8) else { throw ImportError.epubCorrupt }
    let regex = try NSRegularExpression(pattern: #"full-path\s*=\s*["']([^"']+)["']"#)
    guard let m = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
          let r = Range(m.range(at: 1), in: xml) else { throw ImportError.epubCorrupt }
    return String(xml[r])
  }

  static func parseOPF(_ opf: Data, opfPath: String) throws -> Meta {
    guard var xml = String(data: opf, encoding: .utf8) else { throw ImportError.epubCorrupt }
    xml = xml.replacingOccurrences(of: "opf:", with: "")
    var meta = Meta()
    let titleRegex = try NSRegularExpression(pattern: #"<title[^>]*>([\s\S]*?)</title>"#, options: .dotMatchesLineSeparators)
    if let tm = titleRegex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
       let tr = Range(tm.range(at: 1), in: xml) {
      meta.bookTitle = String(xml[tr]).strippedTags.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var hrefById: [String: String] = [:]
    var titleById: [String: String] = [:]
    let itemRegex = try NSRegularExpression(pattern: #"<item\b[^>]*>"#, options: .dotMatchesLineSeparators)
    let ns = xml as NSString
    for m in itemRegex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml)) {
      let tag = ns.substring(with: m.range)
      if let id = attr(tag, "id"), let href = attr(tag, "href") {
        hrefById[id] = href
        if let title = attr(tag, "title") { titleById[id] = title }
      }
    }
    if let spineRange = xml.range(of: #"<spine\b[\s\S]*?</spine>"#, options: .regularExpression) {
      let spineXml = String(xml[spineRange])
      let itemRefRegex = try NSRegularExpression(pattern: #"<itemref\b[^>]*>"#, options: [])
      let sns = spineXml as NSString
      for m in itemRefRegex.matches(in: spineXml, range: NSRange(spineXml.startIndex..., in: spineXml)) {
        let tag = sns.substring(with: m.range)
        if let idref = attr(tag, "idref"), let href = hrefById[idref] {
          let resolved = resolveHref(href, opfPath: opfPath)
          meta.spine.append(resolved)
          if let title = titleById[idref] { meta.titles[resolved] = title }
        }
      }
    }
    if meta.bookTitle.isEmpty { meta.bookTitle = meta.fallbackTitle }
    return meta
  }

  private static func attr(_ tag: String, _ name: String) -> String? {
    let regex = try? NSRegularExpression(pattern: #"\#(name)\s*=\s*["']([^"']*)["']"#)
    guard let r = regex?.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
          let rr = Range(r.range(at: 1), in: tag) else { return nil }
    return String(tag[rr])
  }

  private static func resolveHref(_ href: String, opfPath: String) -> String {
    let cleaned = href.split(separator: "#").first.map(String.init) ?? href
    guard !opfPath.isEmpty else { return cleaned }
    let base = (opfPath as NSString).deletingLastPathComponent
    guard !base.isEmpty else { return cleaned }
    let combined = "\(base)/\(cleaned)".replacingOccurrences(of: "//", with: "/")
    let parts = combined.components(separatedBy: "/")
    var stack: [String] = []
    for p in parts where !p.isEmpty {
      if p == ".." { _ = stack.popLast() } else { stack.append(p) }
    }
    return stack.joined(separator: "/")
  }
}

struct EpubText {
  static func strip(html: String) -> String {
    var s = html
    s = s.replacingOccurrences(of: #"(?i)</(h[1-6]|p|div|br|li|tr|section)>"#, with: "\n", options: .regularExpression)
    s = s.replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
    s = s.replacingOccurrences(of: #"(?i)<[^>]+>"#, with: "", options: .regularExpression)
    s = s.replacingOccurrences(of: "&nbsp;", with: " ")
    s = s.replacingOccurrences(of: "&amp;", with: "&")
    s = s.replacingOccurrences(of: "&lt;", with: "<")
    s = s.replacingOccurrences(of: "&gt;", with: ">")
    s = s.replacingOccurrences(of: "&quot;", with: "\"")
    s = s.replacingOccurrences(of: "&#39;", with: "'")
    s = stripNumericEntities(s)
    s = s.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
    s = s.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func stripNumericEntities(_ html: String) -> String {
    let regex = try! NSRegularExpression(pattern: #"&#(\d+);"#)
    let ns = html as NSString
    let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
    var out = html
    for m in matches.reversed() {
      guard let r = Range(m.range(at: 1), in: html),
            let code = UInt32(html[r]),
            let scalar = UnicodeScalar(code) else { continue }
      let whole = ns.substring(with: m.range)
      out = out.replacingOccurrences(of: whole, with: String(Character(scalar)))
    }
    return out
  }
}

private extension String {
  var strippedTags: String {
    replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

private extension Data {
  func uint32(at i: Int) -> UInt32 {
    guard i + 4 <= count else { return 0 }
    return UInt32(self[i]) | (UInt32(self[i + 1]) << 8) | (UInt32(self[i + 2]) << 16) | (UInt32(self[i + 3]) << 24)
  }
  func uint16(at i: Int) -> UInt16 {
    guard i + 2 <= count else { return 0 }
    return UInt16(self[i]) | (UInt16(self[i + 1]) << 8)
  }
}
