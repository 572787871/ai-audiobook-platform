import Foundation

enum TXTFileReader {
    static func detectEncoding(from data: Data) -> String.Encoding {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return .utf8 }
        if data.starts(with: [0xFF, 0xFE]) { return .utf16LittleEndian }
        if data.starts(with: [0xFE, 0xFF]) { return .utf16BigEndian }

        let candidates: [String.Encoding] = [
            .utf8,
            .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))),
            .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))),
            .utf16LittleEndian, .utf16BigEndian
        ]
        for enc in candidates {
            if canDecode(data, as: enc) { return enc }
        }
        return .utf8
    }

    static func readTextFile(url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let encoding = detectEncoding(from: data)
        guard let text = String(data: data, encoding: encoding) else {
            throw NSError(domain: "TXTReader", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "无法解码文件，编码：\(encoding)"])
        }
        return text
    }

    private static func canDecode(_ data: Data, as encoding: String.Encoding) -> Bool {
        guard let text = String(data: data, encoding: encoding) else { return false }
        return text.count > 0 && !text.contains("\u{FFFD}")
    }
}

// MARK: - Chapter Parser

struct ChapterInfo {
    let index: Int
    let title: String
    let startOffset: Int
    let endOffset: Int
}

struct ChapterList {
    let chapters: [ChapterInfo]
    let totalCharacters: Int

    func chapterIndex(at offset: Int) -> Int {
        var lo = 0, hi = max(0, chapters.count - 1), ans = 0
        while lo <= hi {
            let mid = (lo + hi) / 2
            if chapters[mid].startOffset <= offset {
                ans = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return ans
    }
}

enum TXTChapterParser {
    static let patterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "^\\s*(第[零一二三四五六七八九十百千0-9]+[章回卷节部篇集][^\\n]*)\\s*$", options: .anchorsMatchLines),
        try! NSRegularExpression(pattern: "^\\s*(楔子|序言|序章|引子|前言|番外|尾声|后记|附录)[^\\n]*\\s*$", options: .anchorsMatchLines),
        try! NSRegularExpression(pattern: "^\\s*([一二三四五六七八九十百千]+(?:、|\\.|\\s))\\S{0,30}$", options: .anchorsMatchLines),
    ]

    static func parse(_ text: String) -> ChapterList {
        let total = text.count
        if text.isEmpty { return ChapterList(chapters: [], totalCharacters: 0) }

        let nsText = text as NSString
        var matches: [(Int, String)] = []

        for pattern in patterns {
            pattern.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { result, _, _ in
                guard let r = result, r.numberOfRanges > 0 else { return }
                let range = r.range(at: 0)
                let title = nsText.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
                matches.append((range.location, title))
            }
            if !matches.isEmpty { break }
        }

        matches.sort { $0.0 < $1.0 }

        if matches.isEmpty {
            return ChapterList(chapters: [ChapterInfo(index: 0, title: "正文", startOffset: 0, endOffset: total)],
                             totalCharacters: total)
        }

        var chapters: [ChapterInfo] = []
        if matches[0].0 > 0 {
            chapters.append(ChapterInfo(index: 0, title: "正文", startOffset: 0, endOffset: matches[0].0))
        }
        for i in 0..<matches.count {
            let start = matches[i].0
            let end = i + 1 < matches.count ? matches[i + 1].0 : total
            chapters.append(ChapterInfo(index: chapters.count, title: matches[i].1, startOffset: start, endOffset: end))
        }

        return ChapterList(chapters: chapters, totalCharacters: total)
    }
}
