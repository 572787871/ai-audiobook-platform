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
  var fontSize: CGFloat = 20
  var lineSpacing: CGFloat = 12
  var horizontalPadding: CGFloat = 30
  var palette: ReaderPalette = .paper
  var eyeCare = false
}
