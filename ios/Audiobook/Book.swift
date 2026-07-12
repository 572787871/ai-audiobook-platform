import Foundation
import SwiftData

@Model
final class Book {
  @Attribute(.unique) var id: UUID
  var title: String
  var author: String
  var content: String
  var format: String
  var createdAt: Date
  var updatedAt: Date
  var lastReadOffset: Int
  var progress: Double
  var isCompleted: Bool
  var coverSeed: Int

  init(title: String, author: String = "", content: String, format: String = "txt") {
    id = UUID()
    self.title = title
    self.author = author
    self.content = content
    self.format = format
    createdAt = .now
    updatedAt = .now
    lastReadOffset = 0
    progress = 0
    isCompleted = false
    coverSeed = abs(title.hashValue)
  }
}

struct Chapter: Identifiable, Equatable {
  let id: Int
  let title: String
  let start: Int
  let end: Int
}

enum ChapterParser {
  private static let pattern = #"(?m)^\s*(第[0-9零一二三四五六七八九十百千万两]+[章节回卷篇部].*)$"#

  static func parse(_ text: String) -> [Chapter] {
    let source = text as NSString
    let regex = try? NSRegularExpression(pattern: pattern)
    let matches = regex?.matches(in: text, range: NSRange(location: 0, length: source.length)) ?? []
    guard !matches.isEmpty else {
      return [Chapter(id: 0, title: "正文", start: 0, end: source.length)]
    }
    var chapters: [Chapter] = []
    if matches[0].range.location > 0 {
      chapters.append(Chapter(id: 0, title: "序章", start: 0, end: matches[0].range.location))
    }
    for (index, match) in matches.enumerated() {
      let start = match.range.location
      let end = index + 1 < matches.count ? matches[index + 1].range.location : source.length
      let titleRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
      chapters.append(Chapter(id: chapters.count, title: source.substring(with: titleRange), start: start, end: end))
    }
    return chapters
  }
}
