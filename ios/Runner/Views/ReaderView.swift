import SwiftUI

struct ReaderView: View {
    let book: Book
    @StateObject private var engine = ReaderEngine()
    @StateObject private var tts = SystemTTSEngine()
    @State private var showToolbar = false
    @State private var showSettings = false
    @State private var showTOC = false
    @State private var showTTS = false
    @State private var tempSettings = ReaderSettings()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 正文背景
                engine.settings.backgroundColor.ignoresSafeArea()

                if engine.pages.isEmpty {
                    ProgressView()
                } else {
                    // 正文
                    CoreTextPageView(
                        attributedText: engine.currentPage ?? NSAttributedString(),
                        backgroundColor: engine.settings.backgroundColor
                    )
                    .padding(.horizontal, engine.settings.horizontalPadding)
                    .padding(.vertical, engine.settings.verticalPadding + 60)
                }

                // 手势层
                ReaderTapOverlay(
                    onPrev: { _ = engine.prevPage() },
                    onToggle: { withAnimation(.easeInOut(duration: 0.2)) { showToolbar.toggle() } },
                    onNext: { _ = engine.nextPage() }
                )

                // 底部进度条（沉浸态）
                if !showToolbar {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(engine.currentPageIndex + 1)/\(engine.totalPages)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 8)
                                .padding(.trailing, 16)
                        }
                    }
                }

                // 顶部栏
                if showToolbar {
                    VStack {
                        ReaderTopBar(
                            title: book.title,
                            chapter: engine.currentChapterTitle,
                            onBack: { BookStore.shared.save(saveProgress()) },
                            onTOC: { showTOC = true },
                            onSettings: { tempSettings = engine.settings; showSettings = true },
                            onTTS: { showTTS = true }
                        )
                        Spacer()
                        ReaderBottomBar(
                            chapterIndex: engine.chapterIndex,
                            chapterCount: engine.chapters.count,
                            pageIndex: engine.currentPageIndex,
                            pageCount: engine.totalPages,
                            onPrevChapter: { _ = engine.prevPage() },
                            onNextChapter: { _ = engine.nextPage() },
                            onSliderChange: { _ in }
                        )
                    }
                    .transition(.opacity)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadBook()
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView(
                settings: $tempSettings,
                onApply: { engine.settings = tempSettings; engine.paginateCurrentChapter() },
                onDismiss: { showSettings = false }
            )
        }
        .sheet(isPresented: $showTOC) {
            TOCView(chapters: engine.chapters, currentIndex: engine.chapterIndex) { index in
                engine.goToChapter(index)
                showTOC = false
            }
        }
        .sheet(isPresented: $showTTS) {
            TTSPanelView(engine: engine, tts: tts)
        }
    }

    private func loadBook() async {
        do {
            let text = try String(contentsOfFile: book.filePath, encoding: .utf8)
            let chapters = TXTChapterParser.parse(text)
            engine.load(text: text, chapters: chapters, at: book.lastReadOffset)
        } catch {
            print("Load error: \(error)")
        }
    }

    private func saveProgress() -> Book {
        var b = book
        b.lastReadOffset = engine.currentOffset
        b.chapterIndex = engine.chapterIndex
        b.pageIndex = engine.currentPageIndex
        b.readingProgress = engine.readingProgress
        b.lastReadAt = Date()
        b.updatedAt = Date()
        return b
    }
}

// MARK: - CoreText 页面渲染
struct CoreTextPageView: UIViewRepresentable {
    let attributedText: NSAttributedString
    let backgroundColor: UIColor

    func makeUIView(context: Context) -> CoreTextView {
        let view = CoreTextView()
        view.backgroundColor = backgroundColor
        return view
    }

    func updateUIView(_ uiView: CoreTextView, context: Context) {
        uiView.attributedText = attributedText
        uiView.backgroundColor = backgroundColor
        uiView.setNeedsDisplay()
    }
}

class CoreTextView: UIView {
    var attributedText: NSAttributedString = NSAttributedString()

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        let path = CGPath(rect: bounds, transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        CTFrameDraw(frame, ctx)
    }
}

// MARK: - 手势层
struct ReaderTapOverlay: View {
    let onPrev: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let edge: CGFloat = 24
            let zoneW = (w - edge) / 3
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: edge)
                    .contentShape(Rectangle())
                Color.clear
                    .frame(width: zoneW)
                    .contentShape(Rectangle())
                    .onTapGesture { onPrev() }
                Color.clear
                    .frame(width: zoneW)
                    .contentShape(Rectangle())
                    .onTapGesture { onToggle() }
                Color.clear
                    .frame(width: zoneW)
                    .contentShape(Rectangle())
                    .onTapGesture { onNext() }
            }
        }
    }
}

// MARK: - 顶部栏
struct ReaderTopBar: View {
    let title: String
    let chapter: String
    let onBack: () -> Void
    let onTOC: () -> Void
    let onSettings: () -> Void
    let onTTS: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Button(action: { onBack(); dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
            }
            .padding(.leading, 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if !chapter.isEmpty {
                    Text(chapter)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            Button(action: onTTS) {
                Image(systemName: "headphones")
                    .font(.system(size: 16))
            }
            Button(action: onTOC) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16))
            }
            Button(action: onSettings) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 50)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - 底部栏
struct ReaderBottomBar: View {
    let chapterIndex: Int
    let chapterCount: Int
    let pageIndex: Int
    let pageCount: Int
    let onPrevChapter: () -> Void
    let onNextChapter: () -> Void
    let onSliderChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onPrevChapter) {
                    Image(systemName: "chevron.left")
                }
                Slider(value: Binding(
                    get: { pageCount > 1 ? Double(pageIndex) / Double(pageCount - 1) : 0 },
                    set: onSliderChange
                ))
                Button(action: onNextChapter) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal, 12)

            Text("第\(chapterIndex + 1)/\(chapterCount)章 · \(pageIndex + 1)/\(pageCount)页")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 40)
        .padding(.top, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - 设置面板
struct ReaderSettingsView: View {
    @Binding var settings: ReaderSettings
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("字号") {
                    HStack {
                        Button("A-") { if settings.fontSize > 12 { settings.fontSize -= 2 } }
                        Text("\(Int(settings.fontSize))")
                            .frame(width: 40)
                            .font(.system(size: settings.fontSize))
                        Button("A+") { if settings.fontSize < 36 { settings.fontSize += 2 } }
                    }
                    .buttonStyle(.bordered)
                }

                Section("字体") {
                    ForEach(["PingFang SC", "STSongti-SC-Regular", "STHeitiSC-Light", "STKaitiSC-Regular"], id: \.self) { name in
                        Button(action: { settings.fontName = name }) {
                            HStack {
                                Text(fontLabel(name))
                                    .font(.system(size: 16))
                                Spacer()
                                if settings.fontName == name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section("阅读背景") {
                    ForEach(backgrounds, id: \.name) { bg in
                        Button(action: {
                            settings.backgroundColor = bg.color
                            settings.textColor = bg.textColor
                        }) {
                            HStack {
                                Circle()
                                    .fill(Color(bg.color))
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().stroke(Color.secondary.opacity(0.3)))
                                Text(bg.name)
                                    .padding(.leading, 8)
                                Spacer()
                                if settings.backgroundColor == bg.color {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section("翻页方式") {
                    ForEach(PageAnimation.allCases, id: \.self) { anim in
                        Button(action: { settings.pageAnimation = anim }) {
                            HStack {
                                Text(anim.label)
                                Spacer()
                                if settings.pageAnimation == anim {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") { onApply(); onDismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onDismiss() }
                }
            }
        }
    }

    private let backgrounds: [(name: String, color: UIColor, textColor: UIColor)] = [
        ("米黄", UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1), UIColor(red: 0.23, green: 0.18, blue: 0.10, alpha: 1)),
        ("白色", .white, .black),
        ("护眼绿", UIColor(red: 0.78, green: 0.93, blue: 0.80, alpha: 1), .black),
        ("深灰", UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1), UIColor(red: 0.84, green: 0.84, blue: 0.86, alpha: 1)),
        ("纯黑", .black, UIColor(red: 0.84, green: 0.84, blue: 0.86, alpha: 1)),
    ]

    private func fontLabel(_ name: String) -> String {
        switch name {
        case "PingFang SC": return "苹方"
        case "STSongti-SC-Regular": return "宋体"
        case "STHeitiSC-Light": return "黑体"
        case "STKaitiSC-Regular": return "楷体"
        default: return name
        }
    }
}

// MARK: - 目录
struct TOCView: View {
    let chapters: [ChapterInfo]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            List(Array(chapters.enumerated()), id: \.offset) { i, ch in
                Button(action: { onSelect(i) }) {
                    HStack {
                        Text(ch.title)
                            .font(.subheadline)
                            .foregroundColor(i == currentIndex ? .accentColor : .primary)
                            .fontWeight(i == currentIndex ? .bold : .regular)
                        Spacer()
                        if i == currentIndex {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - TTS 面板
struct TTSPanelView: View {
    @ObservedObject var engine: ReaderEngine
    @ObservedObject var tts: SystemTTSEngine
    @State private var rate: Float = 0.5
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(engine.currentChapterTitle)
                    .font(.headline)
                    .padding(.top)

                if !tts.currentSentence.isEmpty {
                    Text(tts.currentSentence)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                }

                Spacer()

                HStack(spacing: 40) {
                    Button(action: { tts.prevSentence() }) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }
                    Button(action: {
                        if tts.isPlaying { _ = tts.pause() }
                        else if tts.isPaused { _ = tts.resume() }
                        else { tts.speak(text: engine.currentPage?.string ?? "", rate: rate) }
                    }) {
                        Image(systemName: tts.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                    }
                    Button(action: { tts.nextSentence() }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                }

                HStack {
                    Text("语速")
                        .font(.caption)
                    Slider(value: $rate, in: 0.3...0.8) { _ in
                        if tts.isPlaying {
                            tts.stop()
                            tts.speak(text: engine.currentPage?.string ?? "", rate: rate)
                        }
                    }
                    .frame(width: 150)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("听书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") {
                        tts.stop()
                        dismiss()
                    }
                }
            }
        }
    }
}
