import SwiftData
import SwiftUI

struct ReaderView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  let book: Book
  @State private var settings = ReaderSettings()
  @State private var pages: [ReaderPage] = []
  @State private var pageIndex = 0
  @State private var toolbarVisible = false
  @State private var showingDirectory = false
  @State private var showingSettings = false
  @State private var showingNarration = false
  @State private var narration = NarrationController()
  @State private var isPaginating = false

  private var chapters: [Chapter] { ChapterParser.parse(book.content) }
  private var currentChapterIndex: Int {
    let offset = pages[safe: pageIndex]?.range.location ?? book.lastReadOffset
    return chapters.lastIndex { $0.start <= offset } ?? 0
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        settings.palette.background.ignoresSafeArea()
        if pages.isEmpty || isPaginating {
          ProgressView("正在排版…")
        } else {
          NativePageCurlView(
            pages: pages,
            currentIndex: $pageIndex,
            background: UIColor(settings.palette.background),
            foreground: UIColor(settings.palette.foreground),
            fontSize: settings.fontSize,
            lineSpacing: settings.lineSpacing,
            horizontalPadding: settings.horizontalPadding,
            onCenterTap: { withAnimation(.easeInOut(duration: 0.2)) { toolbarVisible.toggle() } }
          )
          progressFooter
        }
        if toolbarVisible { toolbars.transition(.opacity) }
        if narration.playbackState != .stopped {
          AudioFloatingPanel(
            controller: narration,
            onExpand: { showingNarration = true },
            onClose: { narration.stop() }
          )
        }
      }
      .task(id: paginationKey(for: proxy.size)) { await repaginate(size: proxy.size) }
    }
    .navigationBarBackButtonHidden(true)
    .onAppear { configureNarrationCallbacks() }
    .onChange(of: pageIndex) { _, _ in saveProgress() }
    .sheet(isPresented: $showingDirectory) {
      DirectoryView(book: book, pageIndex: $pageIndex, pages: pages)
    }
    .sheet(isPresented: $showingSettings) {
      ReaderSettingsView(settings: settings) {}
    }
    .sheet(isPresented: $showingNarration) {
      NarrationPanelView(
        controller: narration,
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        onSelectChapter: startNarratingChapter
      )
    }
    .onDisappear {
      saveProgress()
      narration.onSegmentChanged = nil
      narration.shutdown()
    }
  }

  private var toolbars: some View {
    VStack {
      HStack {
        Button { dismiss() } label: { Image(systemName: "chevron.left") }
        Spacer()
        Text(book.title).font(.headline).lineLimit(1)
        Spacer()
        Button { openNarration() } label: { Image(systemName: "headphones") }
        Menu {
          Button("回到开头") { pageIndex = 0 }
          Button("停止听书", role: .destructive) { narration.stop() }
            .disabled(narration.playbackState == .stopped)
        } label: { Image(systemName: "ellipsis") }
      }
      .padding().padding(.top, 34).background(.ultraThinMaterial)
      Spacer()
      VStack(spacing: 8) {
        HStack {
          Button("上一章") { moveChapter(by: -1) }.disabled(currentChapterIndex == 0)
          Slider(
            value: Binding(get: { Double(pageIndex) }, set: { pageIndex = Int($0.rounded()) }),
            in: 0...Double(max(1, pages.count - 1)),
            step: 1
          )
          Button("下一章") { moveChapter(by: 1) }.disabled(currentChapterIndex >= chapters.count - 1)
        }.font(.caption)
        HStack {
          toolbarButton("目录", "list.bullet") { showingDirectory = true }
          toolbarButton("夜间", "moon") { settings.palette = settings.palette == .night ? .paper : .night }
          toolbarButton("设置", "textformat.size") { showingSettings = true }
          toolbarButton("听书", "headphones") { openNarration() }
        }
      }.padding().background(.ultraThinMaterial)
    }.ignoresSafeArea(edges: [.top, .bottom])
  }

  private func toolbarButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack { Image(systemName: icon); Text(title).font(.caption2) }.frame(maxWidth: .infinity)
    }.buttonStyle(.plain)
  }

  private var progressFooter: some View {
    let sourceLength = max(1, (book.content as NSString).length)
    let range = pages[safe: pageIndex]?.range ?? NSRange(location: 0, length: 0)
    let progress = Double(min(sourceLength, NSMaxRange(range))) / Double(sourceLength)
    return VStack {
      Spacer()
      HStack {
        Text(chapters[safe: currentChapterIndex]?.title ?? "正文").lineLimit(1)
        Spacer()
        Text("\(pageIndex + 1)/\(max(1, pages.count)) · \(String(format: "%.1f%%", progress * 100))")
      }
      .font(.caption2)
      .foregroundStyle(settings.palette.foreground.opacity(0.55))
      .padding(.horizontal, 18).padding(.bottom, 6)
    }
  }

  private func paginationKey(for size: CGSize) -> PaginationKey {
    PaginationKey(
      width: Int(size.width.rounded()),
      height: Int(size.height.rounded()),
      fontSize: settings.fontSize,
      lineSpacing: settings.lineSpacing,
      horizontalPadding: settings.horizontalPadding
    )
  }

  @MainActor
  private func repaginate(size: CGSize) async {
    guard size.width > 20, size.height > 20 else { return }
    let sourceLength = (book.content as NSString).length
    let legacyOffset = Int(book.progress * Double(sourceLength))
    let anchor = pages[safe: pageIndex]?.range.location ?? (book.lastReadOffset > 0 ? book.lastReadOffset : legacyOffset)
    let configuration = ReaderPaginationConfiguration(
      size: size,
      fontSize: settings.fontSize,
      lineSpacing: settings.lineSpacing,
      horizontalPadding: settings.horizontalPadding
    )
    isPaginating = true
    let text = book.content
    let result = await Task.detached(priority: .userInitiated) {
      ReaderPaginator.paginate(text: text, configuration: configuration)
    }.value
    guard !Task.isCancelled else { return }
    pages = result
    pageIndex = ReaderPaginator.pageIndex(containingUTF16Offset: anchor, pages: result)
    isPaginating = false
  }

  private func saveProgress() {
    guard let page = pages[safe: pageIndex] else { return }
    let sourceLength = max(1, (book.content as NSString).length)
    book.lastReadOffset = page.range.location
    book.progress = Double(page.range.location) / Double(sourceLength)
    book.isCompleted = NSMaxRange(page.range) >= sourceLength
    book.updatedAt = .now
    try? context.save()
  }

  private func moveChapter(by delta: Int) {
    let target = min(max(0, currentChapterIndex + delta), chapters.count - 1)
    guard chapters.indices.contains(target) else { return }
    pageIndex = ReaderPaginator.pageIndex(containingUTF16Offset: chapters[target].start, pages: pages)
  }

  private func configureNarrationCallbacks() {
    narration.onSegmentChanged = { segment in
      pageIndex = ReaderPaginator.pageIndex(containingUTF16Offset: segment.sourceRange.location, pages: pages)
      toolbarVisible = false
    }
  }

  private func openNarration() {
    if narration.playbackState == .stopped {
      let offset = pages[safe: pageIndex]?.range.location ?? book.lastReadOffset
      narration.start(text: book.content, title: book.title, fromUTF16Offset: offset)
    }
    showingNarration = true
  }

  private func startNarratingChapter(_ index: Int) {
    guard chapters.indices.contains(index) else { return }
    let offset = chapters[index].start
    pageIndex = ReaderPaginator.pageIndex(containingUTF16Offset: offset, pages: pages)
    narration.start(text: book.content, title: book.title, fromUTF16Offset: offset)
  }
}

private struct PaginationKey: Equatable {
  let width: Int
  let height: Int
  let fontSize: CGFloat
  let lineSpacing: CGFloat
  let horizontalPadding: CGFloat
}

extension Collection {
  subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
