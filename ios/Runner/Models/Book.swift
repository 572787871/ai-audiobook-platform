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
    var chapters: [Chapter] = []

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

// MARK: - Page Turn Style
enum PageTurnStyle: String, CaseIterable, Codable {
    case curl = "仿真翻页"
    case slide = "滑动" 
    case none = "无动画"
    case scroll = "连续滚动"
    
    var label: String { rawValue }
}

// MARK: - Reader Settings
struct ReaderSettings: Codable {
    var fontSize: CGFloat = 20
    var fontName: String = "PingFang SC"
    var lineHeight: CGFloat = 1.8
    var paragraphSpacing: CGFloat = 12
    var horizontalPadding: CGFloat = 24
    var verticalPadding: CGFloat = 16
    var backgroundColorData: Data?
    var textColorData: Data?
    var pageTurnStyle: PageTurnStyle = .curl
    
    var backgroundColor: UIColor {
        get {
            if let data = backgroundColorData,
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
                return color
            }
            return UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1)
        }
        set {
            backgroundColorData = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false)
        }
    }
    
    var textColor: UIColor {
        get {
            if let data = textColorData,
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
                return color
            }
            return UIColor(red: 0.23, green: 0.18, blue: 0.10, alpha: 1)
        }
        set {
            textColorData = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false)
        }
    }
    
    static let `default` = ReaderSettings()
}

// MARK: - Background Theme
struct ReaderTheme {
    let name: String
    let backgroundColor: UIColor
    let textColor: UIColor
    
    static let themes: [ReaderTheme] = [
        ReaderTheme(name: "米黄", backgroundColor: UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1),
                   textColor: UIColor(red: 0.23, green: 0.18, blue: 0.10, alpha: 1)),
        ReaderTheme(name: "白色", backgroundColor: .white, textColor: .black),
        ReaderTheme(name: "护眼绿", backgroundColor: UIColor(red: 0.78, green: 0.93, blue: 0.80, alpha: 1),
                   textColor: .black),
        ReaderTheme(name: "深灰", backgroundColor: UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1),
                   textColor: UIColor(red: 0.84, green: 0.84, blue: 0.86, alpha: 1)),
        ReaderTheme(name: "纯黑", backgroundColor: .black,
                   textColor: UIColor(red: 0.84, green: 0.84, blue: 0.86, alpha: 1)),
    ]
}

// MARK: - Reading Position
struct ReadingPosition: Codable {
    let chapterIndex: Int
    let charOffset: Int
    let globalPage: Int
    
    static func start() -> ReadingPosition {
        ReadingPosition(chapterIndex: 0, charOffset: 0, globalPage: 0)
    }
}
