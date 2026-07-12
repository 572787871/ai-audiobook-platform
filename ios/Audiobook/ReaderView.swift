import SwiftData
import SwiftUI

struct ReaderView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  let book: Book
  @State private var settings = ReaderSettings()
  @State private var pages: [String] = []
  @State private var pageIndex = 0
  @State private var toolbarVisible = false
  @State private var showingDirectory = false
  @State private var showingSettings = false
  @State private var audioVisible = false

  var body: some View {
    ZStack {
      settings.palette.background.ignoresSafeArea()
      if pages.isEmpty {
        ProgressView().task { repaginate() }
      } else {
        NativePageCurlView(
          pages: pages,
          currentIndex: $pageIndex,
          background: UIColor(settings.palette.background),
          foreground: UIColor(settings.palette.foreground),
          fontSize: settings.fontSize,
          onCenterTap: { withAnimation(.easeInOut(duration: 0.2)) { toolbarVisible.toggle() } }
        )
        .ignoresSafeArea()
        progressFooter
      }
      if toolbarVisible { toolbars.transition(.opacity) }
      if audioVisible { AudioFloatingPanel(title: book.title, text: pages[safe: pageIndex] ?? "", onClose: { audioVisible = false }) }
    }
    .navigationBarBackButtonHidden(true)
    .onChange(of: pageIndex) { _, _ in saveProgress() }
    .sheet(isPresented: $showingDirectory) { DirectoryView(book: book, pageIndex: $pageIndex, pages: pages) }
    .sheet(isPresented: $showingSettings) { ReaderSettingsView(settings: settings) { repaginate() } }
    .onDisappear { saveProgress() }
  }

  private var toolbars: some View {
    VStack {
      HStack {
        Button { dismiss() } label: { Image(systemName: "chevron.left") }
        Spacer(); Text(book.title).font(.headline); Spacer()
        Button { audioVisible = true } label: { Image(systemName: "headphones") }
        Image(systemName: "ellipsis")
      }.padding().padding(.top, 34).background(.ultraThinMaterial)
      Spacer()
      VStack(spacing: 8) {
        HStack {
          Button("上一章") { pageIndex = max(0, pageIndex - 1) }
          Slider(value: Binding(get: { Double(pageIndex) }, set: { pageIndex = Int($0.rounded()) }), in: 0...Double(max(1, pages.count - 1)), step: 1)
          Button("下一章") { pageIndex = min(pages.count - 1, pageIndex + 1) }
        }.font(.caption)
        HStack {
          toolbarButton("目录", "list.bullet") { showingDirectory = true }
          toolbarButton("夜间", "moon") { settings.palette = settings.palette == .night ? .paper : .night }
          toolbarButton("设置", "gearshape") { showingSettings = true }
          toolbarButton("听书", "headphones") { audioVisible = true }
        }
      }.padding().background(.ultraThinMaterial)
    }.ignoresSafeArea(edges: [.top, .bottom])
  }

  private func toolbarButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) { VStack { Image(systemName: icon); Text(title).font(.caption2) }.frame(maxWidth: .infinity) }.buttonStyle(.plain)
  }

  private var progressFooter: some View {
    VStack { Spacer(); HStack { Text("\(pageIndex + 1)/\(max(1, pages.count))"); Spacer(); Text(String(format: "%.1f%%", Double(pageIndex + 1) / Double(max(1, pages.count)) * 100)) }.font(.caption2).foregroundStyle(settings.palette.foreground.opacity(0.55)).padding(.horizontal, 18).padding(.bottom, 6) }
  }

  private func repaginate() {
    let source = book.content as NSString
    let charactersPerPage = max(260, Int(720 * (20 / settings.fontSize)))
    var result: [String] = []
    var location = 0
    while location < source.length {
      var length = min(charactersPerPage, source.length - location)
      if location + length < source.length {
        let candidate = source.substring(with: NSRange(location: location, length: length)) as NSString
        let split = candidate.range(of: "\n", options: .backwards)
        if split.location != NSNotFound && split.location > length / 2 { length = split.location + 1 }
      }
      result.append(source.substring(with: NSRange(location: location, length: length)))
      location += length
    }
    pages = result.isEmpty ? [""] : result
    pageIndex = min(max(0, Int(book.progress * Double(max(0, pages.count - 1)))), pages.count - 1)
  }

  private func saveProgress() {
    guard !pages.isEmpty else { return }
    book.progress = Double(pageIndex) / Double(max(1, pages.count - 1))
    book.isCompleted = pageIndex == pages.count - 1
    book.updatedAt = .now
    try? context.save()
  }
}

extension Collection {
  subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
