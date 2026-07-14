import UIKit
import CoreText

// MARK: - PageContent
struct PageContent {
    let attributedString: NSAttributedString
    let pageIndex: Int
    let chapterIndex: Int
}

// MARK: - ChapterLayout
struct ChapterLayout {
    let chapterIndex: Int
    let attributedString: NSAttributedString
    let framesetter: CTFramesetter
    let pageRanges: [CFRange]
    let totalPages: Int
    
    func pageIndex(for charOffset: Int) -> Int {
        for (i, range) in pageRanges.enumerated() {
            if charOffset >= range.location && charOffset < range.location + range.length {
                return i
            }
        }
        return max(0, pageRanges.count - 1)
    }
}

// MARK: - CoreTextPageEngine
@MainActor
final class ReaderEngine: ObservableObject {
    @Published var totalPages: Int = 0
    @Published var currentPage: Int = 0
    @Published var currentChapterIndex: Int = 0
    @Published var isReady: Bool = false
    
    private(set) var chapterTitles: [String] = []
    private(set) var chapterCount: Int = 0
    
    var settings: ReaderSettings = .default
    
    private var layouts: [Int: ChapterLayout] = [:]
    private var spinePageOffsets: [Int] = []
    private var fullText: String = ""
    private var chapters: [ChapterInfo] = []
    private var renderSize: CGSize = .zero
    
    var onPageChanged: ((Int, Int) -> Void)?
    
    // MARK: - Load
    func load(text: String, chapters: [ChapterInfo], at position: (chapterIndex: Int, charOffset: Int)? = nil) {
        self.fullText = text
        self.chapters = chapters
        self.chapterCount = chapters.count
        self.chapterTitles = chapters.map { $0.title }
        self.isReady = false
        
        layouts.removeAll()
        renderSize = calculatePageSize()
        
        let pos = position ?? (chapterIndex: 0, charOffset: 0)
        Task { await paginateAndNavigate(to: pos) }
    }
    
    func updateSettings(_ newSettings: ReaderSettings) {
        let oldPos = readingPosition
        self.settings = newSettings
        renderSize = calculatePageSize()
        layouts.removeAll()
        rebuildSpineOffsets()
        Task { await paginateAndNavigate(to: oldPos) }
    }
    
    private func calculatePageSize() -> CGSize {
        let w = UIScreen.main.bounds.width - settings.horizontalPadding * 2
        let h = UIScreen.main.bounds.height - settings.verticalPadding * 2 - 120
        return CGSize(width: max(w, 60), height: max(h, 100))
    }
    
    // MARK: - Pagination
    private func paginateAndNavigate(to position: (chapterIndex: Int, charOffset: Int)) async {
        let ci = max(0, min(position.chapterIndex, chapterCount - 1))
        await paginateChapter(ci)
        
        if let layout = layouts[ci] {
            let localPage = layout.pageIndex(for: position.charOffset)
            currentChapterIndex = ci
            currentPage = (spinePageOffsets.indices.contains(ci) ? spinePageOffsets[ci] : 0) + localPage
        } else {
            currentChapterIndex = ci
            currentPage = spinePageOffsets.indices.contains(ci) ? spinePageOffsets[ci] : 0
        }
        
        isReady = true
        onPageChanged?(currentChapterIndex, currentPage)
        
        if ci + 1 < chapterCount { Task { await paginateChapter(ci + 1) } }
        if ci > 0 { Task { await paginateChapter(ci - 1) } }
    }
    
    private func paginateChapter(_ index: Int) async {
        guard index >= 0, index < chapters.count, layouts[index] == nil else { return }
        guard !fullText.isEmpty else { return }
        
        let ch = chapters[index]
        let start = fullText.index(fullText.startIndex, offsetBy: ch.startOffset)
        let end = fullText.index(fullText.startIndex, offsetBy: min(ch.endOffset, fullText.count))
        let chapterText = String(fullText[start..<end])
        
        let attrText = buildAttributedString(chapterText)
        let framesetter = CTFramesetterCreateWithAttributedString(attrText)
        let size = renderSize
        
        var ranges: [CFRange] = []
        var range = CFRange(location: 0, length: 0)
        let pathRect = CGRect(origin: .zero, size: size)
        
        while true {
            let path = CGPath(rect: pathRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: range.location, length: 0), path, nil)
            let frameRange = CTFrameGetVisibleStringRange(frame)
            if frameRange.length == 0 { break }
            ranges.append(frameRange)
            range.location = frameRange.location + frameRange.length
            if range.location >= attrText.length { break }
        }
        
        if ranges.isEmpty {
            ranges.append(CFRange(location: 0, length: 0))
        }
        
        let layout = ChapterLayout(
            chapterIndex: index,
            attributedString: attrText,
            framesetter: framesetter,
            pageRanges: ranges,
            totalPages: ranges.count
        )
        layouts[index] = layout
        rebuildSpineOffsets()
    }
    
    private func buildAttributedString(_ text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = settings.fontSize * (settings.lineHeight - 1.0)
        paragraphStyle.paragraphSpacing = settings.paragraphSpacing
        paragraphStyle.firstLineHeadIndent = settings.fontSize * 2
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
    
    private func rebuildSpineOffsets() {
        var offset = 0
        spinePageOffsets = (0..<chapterCount).map { i in
            let start = offset
            offset += layouts[i]?.totalPages ?? 1
            return start
        }
        totalPages = offset
    }
    
    // MARK: - Navigation
    var readingPosition: (chapterIndex: Int, charOffset: Int) {
        let (spine, local) = localPosition(for: currentPage)
        if let layout = layouts[spine], local < layout.pageRanges.count {
            return (spine, Int(layout.pageRanges[local].location))
        }
        return (spine, 0)
    }
    
    var currentChapterTitle: String {
        guard currentChapterIndex < chapterTitles.count else { return "" }
        return chapterTitles[currentChapterIndex]
    }
    
    var readingProgress: Double {
        if totalPages <= 0 { return 0 }
        return Double(currentPage + 1) / Double(totalPages)
    }
    
    func nextPage() -> Bool {
        guard currentPage + 1 < totalPages else { return false }
        currentPage += 1
        updateChapterIndex()
        return true
    }
    
    func prevPage() -> Bool {
        guard currentPage > 0 else { return false }
        currentPage -= 1
        updateChapterIndex()
        return true
    }
    
    func goToChapter(_ index: Int) {
        guard index >= 0, index < chapterCount else { return }
        Task {
            await paginateChapter(index)
            currentChapterIndex = index
            currentPage = spinePageOffsets.indices.contains(index) ? spinePageOffsets[index] : 0
            onPageChanged?(currentChapterIndex, currentPage)
        }
    }
    
    func goToPage(_ page: Int) {
        guard page >= 0, page < totalPages else { return }
        currentPage = page
        updateChapterIndex()
    }
    
    private func updateChapterIndex() {
        let (spine, _) = localPosition(for: currentPage)
        currentChapterIndex = spine
    }
    
    func localPosition(for globalPage: Int) -> (spineIndex: Int, localPage: Int) {
        guard !spinePageOffsets.isEmpty else { return (0, globalPage) }
        var lo = 0, hi = spinePageOffsets.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if spinePageOffsets[mid] <= globalPage { lo = mid }
            else { hi = mid - 1 }
        }
        return (lo, max(0, globalPage - spinePageOffsets[lo]))
    }
    
    // MARK: - Page Content
    func pageContent(for globalPage: Int) -> PageContent? {
        let (spine, local) = localPosition(for: globalPage)
        guard let layout = layouts[spine], local < layout.pageRanges.count else { return nil }
        let range = layout.pageRanges[local]
        let nsRange = NSRange(location: range.location, length: range.length)
        guard nsRange.location + nsRange.length <= layout.attributedString.length else { return nil }
        let pageText = layout.attributedString.attributedSubstring(from: nsRange)
        return PageContent(attributedString: pageText, pageIndex: local, chapterIndex: spine)
    }
    
    func plainText(for globalPage: Int) -> String {
        guard let pc = pageContent(for: globalPage) else { return "" }
        return pc.attributedString.string
    }
    
    var currentPageContent: PageContent? {
        pageContent(for: currentPage)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
