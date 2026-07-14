import AVFoundation
import SwiftUI

struct DirectoryView: View {
  @Environment(\.dismiss) private var dismiss
  let book: Book
  @Binding var pageIndex: Int
  let pages: [ReaderPage]
  var body: some View {
    NavigationStack {
      List(Array(ChapterParser.parse(book.content).enumerated()), id: \.offset) { index, chapter in
        Button {
          pageIndex = ReaderPaginator.pageIndex(containingUTF16Offset: chapter.start, pages: pages)
          dismiss()
        } label: {
          HStack { Text(chapter.title).foregroundStyle(.primary); Spacer(); if index == currentChapter { Image(systemName: "waveform").foregroundStyle(.orange) } }
        }
      }.navigationTitle("目录").toolbar { Button("关闭") { dismiss() } }
    }
  }
  private var currentChapter: Int {
    let offset = pages[safe: pageIndex]?.range.location ?? 0
    return ChapterParser.parse(book.content).lastIndex { $0.start <= offset } ?? 0
  }
}

struct ReaderSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var settings: ReaderSettings
  let onDone: () -> Void
  var body: some View {
    NavigationStack {
      Form {
        Section("字号") { HStack { Button("A-") { settings.fontSize = max(14, settings.fontSize - 1) }; Spacer(); Text("\(Int(settings.fontSize))"); Spacer(); Button("A+") { settings.fontSize = min(36, settings.fontSize + 1) } } }
        Section("排版") {
          VStack(alignment: .leading) {
            Text("行距 \(Int(settings.lineSpacing))").font(.caption).foregroundStyle(.secondary)
            Slider(value: $settings.lineSpacing, in: 4...24, step: 1)
          }
          VStack(alignment: .leading) {
            Text("页边距 \(Int(settings.horizontalPadding))").font(.caption).foregroundStyle(.secondary)
            Slider(value: $settings.horizontalPadding, in: 16...50, step: 2)
          }
        }
        Section("阅读背景") { HStack { ForEach(ReaderPalette.allCases) { palette in Circle().fill(palette.background).frame(width: 36, height: 36).overlay { if settings.palette == palette { Image(systemName: "checkmark") } }.onTapGesture { settings.palette = palette } } } }
        Section { Toggle("护眼模式", isOn: $settings.eyeCare) }
      }.navigationTitle("阅读设置").toolbar { Button("完成") { onDone(); dismiss() } }
    }
  }
}

struct AudioFloatingPanel: View {
  @Bindable var controller: NarrationController
  let onExpand: () -> Void
  let onClose: () -> Void
  var body: some View {
    VStack { Spacer(); VStack(spacing: 12) {
      HStack {
        Image(systemName: "headphones")
        Button(action: onExpand) {
          VStack(alignment: .leading) {
            Text(controller.bookTitle).font(.headline).lineLimit(1)
            Text(controller.isPlaying ? "正在朗读 · \(controller.currentSegmentIndex + 1)/\(max(1, controller.totalSegments))" : "已暂停")
              .font(.caption).foregroundStyle(.secondary)
          }
        }.buttonStyle(.plain)
        Spacer()
        Button(action: onClose) { Image(systemName: "xmark") }
      }
      HStack {
        Button { controller.skipBackward() } label: { Image(systemName: "backward.fill") }
        Spacer()
        Button { controller.toggle() } label: {
          Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 44))
        }
        Spacer()
        Button { controller.skipForward() } label: { Image(systemName: "forward.fill") }
      }
    }.padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18)).shadow(radius: 10).padding(.horizontal, 18).padding(.bottom, 90) }
  }
}

struct NarrationPanelView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var controller: NarrationController
  let chapters: [Chapter]
  let currentChapterIndex: Int
  let onSelectChapter: (Int) -> Void

  private var voices: [AVSpeechSynthesisVoice] {
    AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language.hasPrefix("zh") || $0.language.hasPrefix("en") }
      .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          VStack(spacing: 14) {
            Text(controller.currentSegmentText.isEmpty ? "准备朗读" : controller.currentSegmentText)
              .font(.footnote).foregroundStyle(.secondary).lineLimit(3)
              .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
              Button { selectChapter(max(0, currentChapterIndex - 1)) } label: {
                Label("上一章", systemImage: "backward.fill").labelStyle(.iconOnly)
              }.disabled(currentChapterIndex == 0)
              Spacer()
              Button { controller.toggle() } label: {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 52))
              }
              Spacer()
              Button { selectChapter(min(chapters.count - 1, currentChapterIndex + 1)) } label: {
                Label("下一章", systemImage: "forward.fill").labelStyle(.iconOnly)
              }.disabled(currentChapterIndex >= chapters.count - 1)
            }
            if controller.totalSegments > 1 {
              Slider(
                value: Binding(get: { controller.progress }, set: { controller.seek(toProgress: $0) }),
                in: 0...1
              )
              Text("段落 \(controller.currentSegmentIndex + 1) / \(controller.totalSegments)")
                .font(.caption).foregroundStyle(.secondary)
            }
          }.padding(.vertical, 6)
        }

        Section("目录") {
          Picker("朗读章节", selection: Binding(get: { currentChapterIndex }, set: selectChapter)) {
            ForEach(chapters) { chapter in Text(chapter.title).tag(chapter.id) }
          }
        }

        Section("语音") {
          Picker("系统声音", selection: Binding(get: { controller.voiceIdentifier }, set: controller.updateVoice)) {
            Text("自动选择").tag("")
            ForEach(voices, id: \.identifier) { voice in
              Text("\(voice.name) · \(voice.language)").tag(voice.identifier)
            }
          }
          VStack(alignment: .leading) {
            Text("语速 \(String(format: "%.0f%%", controller.speechRate / AVSpeechUtteranceDefaultSpeechRate * 100))")
              .font(.caption).foregroundStyle(.secondary)
            Slider(
              value: Binding(get: { Double(controller.speechRate) }, set: { controller.updateRate(Float($0)) }),
              in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(min(0.65, AVSpeechUtteranceMaximumSpeechRate)),
              step: 0.05
            )
          }
        }

        Section("定时停止") {
          Picker("时长", selection: Binding(get: { controller.sleepMinutes }, set: controller.setSleepTimer)) {
            Text("不开启").tag(0)
            ForEach([15, 30, 60, 90], id: \.self) { minutes in Text("\(minutes) 分钟").tag(minutes) }
          }.pickerStyle(.inline)
        }

        Section {
          Button("停止听书", role: .destructive) { controller.stop(); dismiss() }
        }
      }
      .navigationTitle("听书")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { Button("完成") { dismiss() } }
    }
  }

  private func selectChapter(_ index: Int) {
    guard chapters.indices.contains(index) else { return }
    onSelectChapter(index)
  }
}
