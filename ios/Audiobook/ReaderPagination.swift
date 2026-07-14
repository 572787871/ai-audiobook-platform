import CoreText
import Foundation
import UIKit

/// A page keeps its UTF-16 source range so reading progress survives repagination.
struct ReaderPage: Identifiable, Equatable, Sendable {
  let id: Int
  let range: NSRange
  let text: String
  let startsMidParagraph: Bool
}

struct ReaderPaginationConfiguration: Equatable, Sendable {
  let size: CGSize
  let fontSize: CGFloat
  let lineSpacing: CGFloat
  let horizontalPadding: CGFloat

  var contentInsets: UIEdgeInsets {
    UIEdgeInsets(top: 70, left: horizontalPadding, bottom: 42, right: horizontalPadding)
  }

  /// CoreText draws in a bottom-left coordinate space after the context is flipped.
  var coreTextRect: CGRect {
    let insets = contentInsets
    return CGRect(
      x: insets.left,
      y: insets.bottom,
      width: max(1, size.width - insets.left - insets.right),
      height: max(1, size.height - insets.top - insets.bottom)
    )
  }
}

/// A compact adaptation of Yuedu Reader's CoreText pagination contract.
/// Pagination and drawing use the same attributed-string builder and geometry.
enum ReaderPaginator {
  static func paginate(text: String, configuration: ReaderPaginationConfiguration) -> [ReaderPage] {
    let source = text as NSString
    guard source.length > 0 else {
      return [ReaderPage(id: 0, range: NSRange(location: 0, length: 0), text: "", startsMidParagraph: false)]
    }

    let attributed = ReaderTypography.attributedString(
      text,
      fontSize: configuration.fontSize,
      lineSpacing: configuration.lineSpacing
    )
    let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
    let path = CGPath(rect: configuration.coreTextRect, transform: nil)
    var pages: [ReaderPage] = []
    var location = 0

    while location < source.length {
      let frame = CTFramesetterCreateFrame(
        framesetter,
        CFRange(location: location, length: 0),
        path,
        nil
      )
      let visible = CTFrameGetVisibleStringRange(frame)
      let fallback = source.rangeOfComposedCharacterSequences(
        for: NSRange(location: location, length: min(1, source.length - location))
      ).length
      let length = max(fallback, min(visible.length, source.length - location))
      let range = NSRange(location: location, length: length)
      let previousCodeUnit = location > 0 ? source.character(at: location - 1) : 10
      let startsMidParagraph = location > 0 && previousCodeUnit != 10 && previousCodeUnit != 13
      pages.append(ReaderPage(
        id: pages.count,
        range: range,
        text: source.substring(with: range),
        startsMidParagraph: startsMidParagraph
      ))
      location += length
    }

    return pages
  }

  static func pageIndex(containingUTF16Offset offset: Int, pages: [ReaderPage]) -> Int {
    guard !pages.isEmpty else { return 0 }
    let clamped = max(0, offset)
    if let index = pages.firstIndex(where: { clamped < NSMaxRange($0.range) }) {
      return index
    }
    return pages.count - 1
  }
}

enum ReaderTypography {
  static func attributedString(
    _ text: String,
    fontSize: CGFloat,
    lineSpacing: CGFloat,
    firstParagraphIsContinuation: Bool = false
  ) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = lineSpacing
    paragraph.paragraphSpacing = max(4, lineSpacing * 0.35)
    paragraph.firstLineHeadIndent = fontSize * 2
    paragraph.lineBreakMode = .byWordWrapping
    let attributed = NSMutableAttributedString(
      string: text,
      attributes: [
        .font: UIFont.systemFont(ofSize: fontSize),
        .paragraphStyle: paragraph,
      ]
    )
    if firstParagraphIsContinuation, attributed.length > 0 {
      let continuation = paragraph.mutableCopy() as! NSMutableParagraphStyle
      continuation.firstLineHeadIndent = 0
      let source = text as NSString
      let newline = source.rangeOfCharacter(from: .newlines)
      let firstParagraphLength = newline.location == NSNotFound ? source.length : NSMaxRange(newline)
      attributed.addAttribute(.paragraphStyle, value: continuation, range: NSRange(location: 0, length: firstParagraphLength))
    }
    return attributed
  }
}

final class CoreTextReaderPageView: UIView {
  private var pageText = ""
  private var fontSize: CGFloat = 20
  private var lineSpacing: CGFloat = 12
  private var horizontalPadding: CGFloat = 30
  private var textColor = UIColor.label
  private var startsMidParagraph = false

  override class var layerClass: AnyClass { CALayer.self }

  func configure(
    text: String,
    startsMidParagraph: Bool,
    fontSize: CGFloat,
    lineSpacing: CGFloat,
    horizontalPadding: CGFloat,
    foreground: UIColor,
    background: UIColor
  ) {
    pageText = text
    self.startsMidParagraph = startsMidParagraph
    self.fontSize = fontSize
    self.lineSpacing = lineSpacing
    self.horizontalPadding = horizontalPadding
    textColor = foreground
    backgroundColor = background
    isOpaque = true
    contentMode = .redraw
    setNeedsDisplay()
  }

  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    context.saveGState()
    context.setFillColor(backgroundColor?.cgColor ?? UIColor.systemBackground.cgColor)
    context.fill(bounds)
    context.translateBy(x: 0, y: bounds.height)
    context.scaleBy(x: 1, y: -1)

    let configuration = ReaderPaginationConfiguration(
      size: bounds.size,
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      horizontalPadding: horizontalPadding
    )
    let attributed = NSMutableAttributedString(
      attributedString: ReaderTypography.attributedString(
        pageText,
        fontSize: fontSize,
        lineSpacing: lineSpacing,
        firstParagraphIsContinuation: startsMidParagraph
      )
    )
    attributed.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: attributed.length))
    let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGPath(rect: configuration.coreTextRect, transform: nil), nil)
    CTFrameDraw(frame, context)
    context.restoreGState()
  }
}
