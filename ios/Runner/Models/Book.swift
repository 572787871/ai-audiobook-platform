import Foundation

struct Book: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var author: String?
    var filePath: String
    var fileSize: Int64
    var encoding: String
    var createdAt: Date
    var updatedAt: Date
    var lastReadOffset: Int
    var chapterIndex: Int
    var pageIndex: Int
    var lastReadChapter: String?
    var readingProgress: Double
    var readingTimeSec: Int
    var lastReadAt: Date?
    var chapterCount: Int
    var isCompleted: Bool
    var coverPath: String?

    init(id: String = UUID().uuidString, title: String, filePath: String, fileSize: Int64,
         encoding: String = "UTF-8") {
        self.id = id
        self.title = title
        self.filePath = filePath
        self.fileSize = fileSize
        self.encoding = encoding
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastReadOffset = 0
        self.chapterIndex = 0
        self.pageIndex = 0
        self.readingProgress = 0.0
        self.readingTimeSec = 0
        self.chapterCount = 0
        self.isCompleted = false
    }
}

struct Chapter: Codable, Equatable {
    let index: Int
    let title: String
    let startOffset: Int
    let endOffset: Int

    var length: Int { endOffset - startOffset }
}
