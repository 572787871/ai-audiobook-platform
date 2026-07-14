import UIKit
import CoreText

// MARK: - 阅读器设置
struct ReaderSettings {
    var fontSize: CGFloat = 20
    var fontName: String = "PingFang SC"
    var lineHeight: CGFloat = 1.8
    var paragraphSpacing: CGFloat = 12
    var horizontalPadding: CGFloat = 24
    var verticalPadding: CGFloat = 16
    var backgroundColor: UIColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1) // 米黄
    var textColor: UIColor = UIColor(red: 0.23, green: 0.18, blue: 0.10, alpha: 1) // 深棕
    var pageAnimation: PageAnimation = .curl
}

enum PageAnimation: String, CaseIterable {
    case none = "无动画"
    case slide = "滑动"
    case curl = "仿真"
    case scroll = "滚动"

    var label: String { rawValue }
}

// MARK: - 分页引擎
@MainActor
final class ReaderEngine: ObservableObject {
    @Published var pages: [NSAttributedString] = []
    @Published var currentPageIndex: Int = 0
    @Published var totalPages: Int = 0
    @Published var chapterIndex: Int = 0
    @Published var chapters: [ChapterInfo] = []
    @Published var currentChapterTitle: String = ""

    var settings = ReaderSettings()
    private var fullText: String = ""
    private var pendingPageIndex: Int = 0

    func load(text: String, chapters: ChapterList, at offset: Int = 0) {
        self.fullText = text
        self.chapters = chapters.chapters
        self.chapterIndex = chapters.chapterIndex(at: offset)
        self.currentChapterTitle = self.chapters[safe: self.chapterIndex]?.title ?? ""
        paginateCurrentChapter()
        let chOffset = offset - self.chapters[safe: chapterIndex]?.startOffset ?? 0
        currentPageIndex = pageIndexForChapterOffset(chOffset)
    }

    func paginateCurrentChapter() {
        guard chapterIndex < chapters.count else { return }
        let ch = chapters[chapterIndex]
        let start = fullText.index(fullText.startIndex, offsetBy: ch.startOffset)
        let end = fullText.index(fullText.startIndex, offsetBy: min(ch.endOffset, fullText.count))
        let chapterText = String(fullText[start..<end])
        pages = paginate(text: chapterText, size: pageSize)
        totalPages = pages.count
    }

    private var pageSize: CGSize {
        let w = UIScreen.main.bounds.width - settings.horizontalPadding * 2
        let h = UIScreen.main.bounds.height - settings.verticalPadding * 2 - 120 // 留出工具栏空间
        return CGSize(width: max(w, 100), height: max(h, 200))
    }

    private func paginate(text: String, size: CGSize) -> [NSAttributedString] {
        let attrText = buildAttributedString(text)
        let framesetter = CTFramesetterCreateWithAttributedString(attrText)
        var pages: [NSAttributedString] = []
        var range = CFRange(location: 0, length: 0)
        let pathRect = CGRect(origin: .zero, size: size)

        while true {
            let path = CGPath(rect: pathRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: range.location, length: 0), path, nil)
            let frameRange = CTFrameGetVisibleStringRange(frame)
            if frameRange.length == 0 { break }
            let pageRange = NSRange(location: frameRange.location, length: frameRange.length)
            let pageText = attrText.attributedSubstring(from: pageRange)
            pages.append(pageText)
            range.location = frameRange.location + frameRange.length
            if range.location >= attrText.length { break }
        }
        return pages
    }

    private func buildAttributedString(_ text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = settings.fontSize * (settings.lineHeight - 1.0)
        paragraphStyle.paragraphSpacing = settings.paragraphSpacing
        paragraphStyle.firstLineHeadIndent = settings.fontSize * 2 // 首行缩进2字符
        paragraphStyle.alignment = .natural

        let font = UIFont(name: settings.fontName, size: settings.fontSize)
            ?? UIFont.systemFont(ofSize: settings.fontSize)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: settings.textColor,
            .paragraphStyle: paragraphStyle
        ]
        return NSAttributedString(string: text, attributes: attrs)
    }

    private func pageIndexForChapterOffset(_ offset: Int) -> Int {
        if offset <= 0 { return 0 }
        var charCount = 0
        for (i, page) in pages.enumerated() {
            charCount += page.length
            if charCount > offset { return i }
        }
        return max(0, pages.count - 1)
    }

    var currentPage: NSAttributedString? {
        guard currentPageIndex < pages.count else { return nil }
        return pages[currentPageIndex]
    }

    var readingProgress: Double {
        if totalPages <= 0 { return 0 }
        return Double(currentPageIndex + 1) / Double(totalPages)
    }

    // MARK: - Navigation
    func nextPage() -> Bool {
        if currentPageIndex + 1 < pages.count {
            currentPageIndex += 1
            return true
        }
        if chapterIndex + 1 < chapters.count {
            chapterIndex += 1
            currentChapterTitle = chapters[chapterIndex].title
            paginateCurrentChapter()
            currentPageIndex = 0
            return true
        }
        return false
    }

    func prevPage() -> Bool {
        if currentPageIndex > 0 {
            currentPageIndex -= 1
            return true
        }
        if chapterIndex > 0 {
            chapterIndex -= 1
            currentChapterTitle = chapters[chapterIndex].title
            paginateCurrentChapter()
            currentPageIndex = pages.count - 1
            return true
        }
        return false
    }

    func goToChapter(_ index: Int) {
        guard index >= 0, index < chapters.count else { return }
        chapterIndex = index
        currentChapterTitle = chapters[index].title
        paginateCurrentChapter()
        currentPageIndex = 0
    }

    var currentOffset: Int {
        let ch = chapters[safe: chapterIndex]
        var offset = ch?.startOffset ?? 0
        for i in 0..<currentPageIndex {
            offset += pages[safe: i]?.length ?? 0
        }
        return offset
    }

    func updateSettingsAndRepaginate(_ newSettings: ReaderSettings) {
        settings = newSettings
        let anchor = currentPageIndex > 0
            ? pages[0..<currentPageIndex].reduce(0) { $0 + $1.length }
            : 0
        paginateCurrentChapter()
        let ch = chapters[safe: chapterIndex]
        currentPageIndex = pageIndexForChapterOffset(anchor + (ch?.startOffset ?? 0) - (ch?.startOffset ?? 0))
        currentPageIndex = min(currentPageIndex, max(0, pages.count - 1))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
