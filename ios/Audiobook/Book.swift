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
  private static let pattern = #"^\s*((?:第[0-9零一二三四五六七八九十百千萬万两]+[章节節回卷篇部]|卷[0-9零一二三四五六七八九十百千萬万两]+|(?:chapter|part)\s*\d+|序章|序言|序幕|前言|引子|引言|楔子|尾声|尾聲|终章|終章|后记|後記|番外|结语|結語|prologue|epilogue|preface|introduction)[^\r\n]*)$"#

  static func parse(_ text: String) -> [Chapter] {
    let source = text as NSString
    let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive])
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
      let title = source.substring(with: titleRange).trimmingCharacters(in: .whitespacesAndNewlines)
      chapters.append(Chapter(id: chapters.count, title: title, start: start, end: end))
    }
    return chapters
  }
}
