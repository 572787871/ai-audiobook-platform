import Foundation
import SwiftUI

enum ReaderPalette: String, CaseIterable, Identifiable {
  case paper, green, white, night
  var id: String { rawValue }
  var background: Color {
    switch self {
    case .paper: Color(red: 0.97, green: 0.94, blue: 0.87)
    case .green: Color(red: 0.90, green: 0.93, blue: 0.82)
    case .white: Color(red: 0.98, green: 0.98, blue: 0.96)
    case .night: Color(red: 0.09, green: 0.10, blue: 0.11)
    }
  }
  var foreground: Color { self == .night ? Color(white: 0.72) : Color(red: 0.15, green: 0.13, blue: 0.10) }
}

@Observable
final class ReaderSettings {
  private let defaults: UserDefaults
  var fontSize: CGFloat { didSet { defaults.set(Double(fontSize), forKey: "reader.fontSize") } }
  var lineSpacing: CGFloat { didSet { defaults.set(Double(lineSpacing), forKey: "reader.lineSpacing") } }
  var horizontalPadding: CGFloat { didSet { defaults.set(Double(horizontalPadding), forKey: "reader.horizontalPadding") } }
  var palette: ReaderPalette { didSet { defaults.set(palette.rawValue, forKey: "reader.palette") } }
  var eyeCare: Bool {
    didSet {
      defaults.set(eyeCare, forKey: "reader.eyeCare")
      if eyeCare, palette != .night { palette = .green }
      if !eyeCare, palette == .green { palette = .paper }
    }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let savedFontSize = defaults.double(forKey: "reader.fontSize")
    let savedLineSpacing = defaults.double(forKey: "reader.lineSpacing")
    let savedPadding = defaults.double(forKey: "reader.horizontalPadding")
    fontSize = savedFontSize > 0 ? CGFloat(savedFontSize) : 20
    lineSpacing = savedLineSpacing > 0 ? CGFloat(savedLineSpacing) : 12
    horizontalPadding = savedPadding > 0 ? CGFloat(savedPadding) : 30
    palette = ReaderPalette(rawValue: defaults.string(forKey: "reader.palette") ?? "") ?? .paper
    eyeCare = defaults.bool(forKey: "reader.eyeCare")
  }
}
