import AVFoundation
import SwiftUI

struct DirectoryView: View {
  @Environment(\.dismiss) private var dismiss
  let book: Book
  @Binding var pageIndex: Int
  let pages: [String]
  var body: some View {
    NavigationStack {
      List(Array(ChapterParser.parse(book.content).enumerated()), id: \.offset) { index, chapter in
        Button { pageIndex = min(pages.count - 1, max(0, Int(Double(chapter.start) / Double(max(1, (book.content as NSString).length)) * Double(pages.count)))); dismiss() } label: {
          HStack { Text(chapter.title).foregroundStyle(.primary); Spacer(); if index == currentChapter { Image(systemName: "waveform").foregroundStyle(.orange) } }
        }
      }.navigationTitle("目录").toolbar { Button("关闭") { dismiss() } }
    }
  }
  private var currentChapter: Int { ChapterParser.parse(book.content).lastIndex { $0.start <= Int(Double(pageIndex) / Double(max(1, pages.count)) * Double((book.content as NSString).length)) } ?? 0 }
}

struct ReaderSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var settings: ReaderSettings
  let onDone: () -> Void
  var body: some View {
    NavigationStack {
      Form {
        Section("字号") { HStack { Button("A-") { settings.fontSize = max(14, settings.fontSize - 1) }; Spacer(); Text("\(Int(settings.fontSize))"); Spacer(); Button("A+") { settings.fontSize = min(36, settings.fontSize + 1) } } }
        Section("阅读背景") { HStack { ForEach(ReaderPalette.allCases) { palette in Circle().fill(palette.background).frame(width: 36, height: 36).overlay { if settings.palette == palette { Image(systemName: "checkmark") } }.onTapGesture { settings.palette = palette } } } }
        Section { Toggle("护眼模式", isOn: $settings.eyeCare) }
      }.navigationTitle("阅读设置").toolbar { Button("完成") { onDone(); dismiss() } }
    }
  }
}

struct AudioFloatingPanel: View {
  let title: String
  let text: String
  let onClose: () -> Void
  @State private var speaker = SystemSpeaker()
  var body: some View {
    VStack { Spacer(); VStack(spacing: 12) {
      HStack { Image(systemName: "headphones"); VStack(alignment: .leading) { Text(title).font(.headline); Text(speaker.playing ? "正在朗读" : "已暂停").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button(action: onClose) { Image(systemName: "xmark") } }
      HStack { Button { } label: { Image(systemName: "backward.fill") }; Spacer(); Button { speaker.toggle(text) } label: { Image(systemName: speaker.playing ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 44)) }; Spacer(); Button { } label: { Image(systemName: "forward.fill") } }
    }.padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18)).shadow(radius: 10).padding(.horizontal, 18).padding(.bottom, 90) }
  }
}

@Observable final class SystemSpeaker: NSObject, AVSpeechSynthesizerDelegate {
  private let synthesizer = AVSpeechSynthesizer()
  var playing = false
  override init() { super.init(); synthesizer.delegate = self }
  func toggle(_ text: String) {
    if synthesizer.isSpeaking { synthesizer.pauseSpeaking(at: .word); playing = false }
    else if synthesizer.isPaused { synthesizer.continueSpeaking(); playing = true }
    else { let utterance = AVSpeechUtterance(string: text); utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN"); synthesizer.speak(utterance); playing = true }
  }
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { playing = false }
}
