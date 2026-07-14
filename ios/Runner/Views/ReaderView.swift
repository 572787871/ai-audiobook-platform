import SwiftUI
import UIKit
import CoreText
import AVFoundation

// MARK: - SwiftUI Reader View (Wrapper)
struct ReaderView: View {
    let book: Book
    @StateObject private var engine = ReaderEngine()
    @StateObject private var ttsCoordinator = TTSCoordinator()
    @State private var showBars = false
    @State private var showSettings = false
    @State private var showTOC = false
    @State private var showTTS = false
    @State private var ttsSettings = TTSSettings()
    @State private var selectedTheme = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                engine.settings.backgroundColor.ignoresSafeArea()
                
                if engine.isReady && engine.totalPages > 0 {
                    // PageView using UIPageViewController
                    CoreTextPageViewRepresentable(
                        engine: engine,
                        pageTurnStyle: engine.settings.pageTurnStyle,
                        currentPage: $engine.currentPage,
                        onPageChanged: { page in
                            saveProgress()
                        }
                    )
                    .ignoresSafeArea()
                    .padding(.horizontal, engine.settings.horizontalPadding)
                    .padding(.vertical, engine.settings.verticalPadding + (showBars ? 100 : 20))
                } else {
                    ProgressView()
                        .tint(.secondary)
                }
                
                // Tap zones
                if !showBars {
                    TapZoneView(
                        onPrev: { _ = engine.prevPage() },
                        onToggle: { withAnimation(.easeInOut(duration: 0.2)) { showBars = true } },
                        onNext: { _ = engine.nextPage() }
                    )
                } else {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showBars = false } }
                }
                
                // Bottom progress
                if !showBars {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(engine.currentPage + 1)/\(engine.totalPages)")
                                .font(.caption2)
                                .foregroundColor(engine.settings.textColor.withAlphaComponent(0.5))
                                .padding(.bottom, 12)
                                .padding(.trailing, 20)
                        }
                    }
                }
                
                // Toolbars
                if showBars {
                    VStack(spacing: 0) {
                        topBar
                        Spacer()
                        bottomBar
                    }
                    .transition(.opacity)
                    .background(Color.black.opacity(0.001))
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showBars = false } }
                }
            }
        }
        .navigationBarHidden(true)
        .task { await loadBook() }
        .onDisappear { saveProgress(); ttsCoordinator.stop() }
        .onChange(of: engine.currentPage) { _ in saveProgress() }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView(
                engine: engine,
                selectedTheme: $selectedTheme,
                onApply: { saveProgress() }
            )
        }
        .sheet(isPresented: $showTOC) {
            TOCView(
                chapters: engine.chapterTitles.enumerated().map { (i, t) in (i, t) },
                currentIndex: engine.currentChapterIndex,
                onSelect: { engine.goToChapter($0); showBars = false }
            )
        }
        .sheet(isPresented: $showTTS) {
            TTSPanelView(
                engine: engine,
                ttsCoordinator: ttsCoordinator,
                settings: $ttsSettings
            )
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button(action: { saveProgress(); dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(engine.settings.textColor)
            }
            .padding(.leading, 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(engine.settings.textColor)
                    .lineLimit(1)
                Text(engine.currentChapterTitle)
                    .font(.caption2)
                    .foregroundColor(engine.settings.textColor.withAlphaComponent(0.6))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            
            Spacer()
            
            Button(action: { showTTS = true }) {
                Image(systemName: "headphones")
                    .font(.system(size: 16))
                    .foregroundColor(engine.settings.textColor)
            }
            .padding(.horizontal, 6)
            Button(action: { showTOC = true }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16))
                    .foregroundColor(engine.settings.textColor)
            }
            .padding(.horizontal, 6)
            Button(action: { showSettings = true }) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 16))
                    .foregroundColor(engine.settings.textColor)
            }
            .padding(.horizontal, 6)
        }
        .padding(.horizontal, 12)
        .padding(.top, 50)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 4) {
            // Chapter slider
            HStack(spacing: 12) {
                Button(action: { if engine.currentChapterIndex > 0 { engine.goToChapter(engine.currentChapterIndex - 1) } }) {
                    Image(systemName: "chevron.left.to.line")
                        .font(.caption)
                        .foregroundColor(engine.settings.textColor)
                }
                
                Slider(
                    value: Binding(
                        get: { engine.totalPages > 1 ? Double(engine.currentPage) / Double(engine.totalPages - 1) : 0 },
                        set: { engine.goToPage(Int($0 * Double(max(1, engine.totalPages - 1)))) }
                    )
                )
                .tint(engine.settings.textColor)
                
                Button(action: { if engine.currentChapterIndex + 1 < engine.chapterCount { engine.goToChapter(engine.currentChapterIndex + 1) } }) {
                    Image(systemName: "chevron.right.to.line")
                        .font(.caption)
                        .foregroundColor(engine.settings.textColor)
                }
            }
            .padding(.horizontal, 16)
            
            HStack {
                Text("第\(engine.currentChapterIndex + 1)/\(engine.chapterCount)章")
                    .font(.caption2)
                    .foregroundColor(engine.settings.textColor.withAlphaComponent(0.6))
                Spacer()
                Text("\(Int(engine.readingProgress * 100))%")
                    .font(.caption2)
                    .foregroundColor(engine.settings.textColor.withAlphaComponent(0.6))
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 40)
        .padding(.top, 8)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Load / Save
    private func loadBook() async {
        do {
            let text = try String(contentsOfFile: book.filePath, encoding: .utf8)
            let chapters = TXTChapterParser.parse(text)
            var settings = loadSettings()
            settings.pageTurnStyle = loadPageTurnStyle()
            engine.settings = settings
            engine.load(text: text, chapters: chapters.chapters,
                       at: (chapterIndex: book.chapterIndex, charOffset: book.lastReadOffset))
        } catch {
            print("Load error: \(error)")
        }
    }
    
    private func saveProgress() {
        var b = book
        let pos = engine.readingPosition
        b.lastReadOffset = pos.charOffset
        b.chapterIndex = pos.chapterIndex
        b.pageIndex = engine.currentPage
        b.readingProgress = engine.readingProgress
        b.lastReadChapter = engine.currentChapterTitle
        b.lastReadAt = Date()
        b.updatedAt = Date()
        if engine.readingProgress >= 1.0 { b.isCompleted = true }
        BookStore.shared.save(b)
        saveSettings(engine.settings)
    }
    
    private func loadSettings() -> ReaderSettings {
        if let data = UserDefaults.standard.data(forKey: "reader_settings"),
           let s = try? JSONDecoder().decode(ReaderSettings.self, from: data) {
            return s
        }
        return .default
    }
    
    private func loadPageTurnStyle() -> PageTurnStyle {
        guard let raw = UserDefaults.standard.string(forKey: "page_turn_style"),
              let style = PageTurnStyle(rawValue: raw) else { return .curl }
        return style
    }
    
    private func saveSettings(_ s: ReaderSettings) {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: "reader_settings")
        }
        UserDefaults.standard.set(s.pageTurnStyle.rawValue, forKey: "page_turn_style")
    }
}

// MARK: - Tap Zone View
struct TapZoneView: View {
    let onPrev: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let zoneW = w / 3
            HStack(spacing: 0) {
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

// MARK: - UIPageViewController Representable
struct CoreTextPageViewRepresentable: UIViewControllerRepresentable {
    let engine: ReaderEngine
    let pageTurnStyle: PageTurnStyle
    @Binding var currentPage: Int
    let onPageChanged: (Int) -> Void
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let options: [UIPageViewController.OptionsKey: Any]
        let transitionStyle: UIPageViewController.TransitionStyle
        let navigationOrientation: UIPageViewController.NavigationOrientation
        
        switch pageTurnStyle {
        case .scroll:
            transitionStyle = .scroll
            navigationOrientation = .vertical
            options = [.interPageSpacing: 8]
        case .curl:
            transitionStyle = .pageCurl
            navigationOrientation = .horizontal
            options = [.spineLocation: UIPageViewController.SpineLocation.min.rawValue]
        case .slide, .none:
            transitionStyle = .scroll
            navigationOrientation = .horizontal
            options = [.interPageSpacing: 0]
        }
        
        let pageVC = UIPageViewController(
            transitionStyle: transitionStyle,
            navigationOrientation: navigationOrientation,
            options: options
        )
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator
        pageVC.view.backgroundColor = .clear
        
        if let initialVC = context.coordinator.viewController(for: currentPage) {
            pageVC.setViewControllers([initialVC], direction: .forward, animated: false)
        }
        
        return pageVC
    }
    
    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        context.coordinator.updateCurrentPage(currentPage, pageVC: uiViewController)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine, pageTurnStyle: pageTurnStyle, currentPage: $currentPage, onPageChanged: onPageChanged)
    }
    
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        let engine: ReaderEngine
        let pageTurnStyle: PageTurnStyle
        @Binding var currentPage: Int
        let onPageChanged: (Int) -> Void
        private var isAnimating = false
        
        init(engine: ReaderEngine, pageTurnStyle: PageTurnStyle, currentPage: Binding<Int>, onPageChanged: @escaping (Int) -> Void) {
            self.engine = engine
            self.pageTurnStyle = pageTurnStyle
            self._currentPage = currentPage
            self.onPageChanged = onPageChanged
        }
        
        func viewController(for page: Int) -> UIViewController? {
            guard page >= 0, page < engine.totalPages,
                  let content = engine.pageContent(for: page) else { return nil }
            let vc = CoreTextPageViewController()
            vc.configure(
                attributedText: content.attributedString,
                backgroundColor: engine.settings.backgroundColor,
                themeTextColor: engine.settings.textColor
            )
            vc.pageIndex = page
            return vc
        }
        
        func updateCurrentPage(_ page: Int, pageVC: UIPageViewController) {
            guard !isAnimating else { return }
            if let currentVC = pageVC.viewControllers?.first as? CoreTextPageViewController,
               currentVC.pageIndex == page { return }
            
            let direction: UIPageViewController.NavigationDirection = page > currentPage ? .forward : .reverse
            if let vc = viewController(for: page) {
                pageVC.setViewControllers([vc], direction: direction, animated: pageTurnStyle != .none) { _ in }
            }
        }
        
        // MARK: - DataSource
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let ctvc = viewController as? CoreTextPageViewController else { return nil }
            return self.viewController(for: ctvc.pageIndex - 1)
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let ctvc = viewController as? CoreTextPageViewController else { return nil }
            return self.viewController(for: ctvc.pageIndex + 1)
        }
        
        // MARK: - Delegate
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            isAnimating = false
            guard completed,
                  let vc = pageViewController.viewControllers?.first as? CoreTextPageViewController else { return }
            currentPage = vc.pageIndex
            onPageChanged(vc.pageIndex)
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            isAnimating = true
        }
    }
}

// MARK: - CoreText Page ViewController
class CoreTextPageViewController: UIViewController {
    var pageIndex: Int = 0
    private var attributedText: NSAttributedString?
    private var backgroundColor: UIColor = .clear
    private var themeTextColor: UIColor = UIColor(red: 0.23, green: 0.18, blue: 0.10, alpha: 1)
    
    func configure(attributedText: NSAttributedString, backgroundColor: UIColor, themeTextColor: UIColor) {
        self.attributedText = attributedText
        self.backgroundColor = backgroundColor
        self.themeTextColor = themeTextColor
    }
    
    override func loadView() {
        let pageView = CoreTextPageView(frame: .zero)
        pageView.backgroundColor = backgroundColor
        pageView.attributedText = attributedText ?? NSAttributedString()
        pageView.contentMode = .redraw
        self.view = pageView
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        (view as? CoreTextPageView)?.setNeedsDisplay()
    }
}

// MARK: - CoreText Drawing View
class CoreTextPageView: UIView {
    var attributedText: NSAttributedString = NSAttributedString()
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), attributedText.length > 0 else { return }
        ctx.textMatrix = CGAffineTransform.identity
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        
        let path = CGPath(rect: bounds.insetBy(dx: 4, dy: 4), transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        CTFrameDraw(frame, ctx)
    }
}

// MARK: - TOC View
struct TOCView: View {
    let chapters: [(Int, String)]
    let currentIndex: Int
    let onSelect: (Int) -> Void
    @State private var searchText = ""
    @State private var reversed = false
    @Environment(\.dismiss) private var dismiss
    
    var filteredChapters: [(Int, String)] {
        let list = reversed ? chapters.reversed() : chapters
        guard !searchText.isEmpty else { return Array(list) }
        return list.filter { $0.1.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    TextField("搜索章节", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    Button(action: { reversed.toggle() }) {
                        Image(systemName: "arrow.up.arrow.down")
                            .padding(.trailing)
                    }
                }
                .padding(.vertical, 8)
                
                List(filteredChapters, id: \.0) { i, title in
                    Button(action: { onSelect(i); dismiss() }) {
                        HStack {
                            Text(title)
                                .font(.subheadline)
                                .foregroundColor(i == currentIndex ? .accentColor : .primary)
                                .fontWeight(i == currentIndex ? .bold : .regular)
                            Spacer()
                            if i == currentIndex {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                            if i < currentIndex {
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                
                HStack {
                    Text("共 \(chapters.count) 章")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("读到第 \(currentIndex + 1) 章")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Settings View
struct ReaderSettingsView: View {
    @ObservedObject var engine: ReaderEngine
    @Binding var selectedTheme: Int
    let onApply: () -> Void
    @State private var tempFontSize: CGFloat
    @State private var tempFontName: String
    @State private var tempLineHeight: CGFloat
    @State private var tempParagraphSpacing: CGFloat
    @State private var tempHPadding: CGFloat
    @State private var tempVPadding: CGFloat
    @State private var tempPageStyle: PageTurnStyle
    @Environment(\.dismiss) private var dismiss
    
    private let fontOptions = [
        ("苹方", "PingFang SC"),
        ("宋体", "STSongti-SC-Regular"),
        ("黑体", "STHeitiSC-Light"),
        ("楷体", "STKaitiSC-Regular"),
        ("圆体", "STYuanti-SC-Regular"),
    ]
    
    init(engine: ReaderEngine, selectedTheme: Binding<Int>, onApply: @escaping () -> Void) {
        self.engine = engine
        self._selectedTheme = selectedTheme
        self.onApply = onApply
        _tempFontSize = State(initialValue: engine.settings.fontSize)
        _tempFontName = State(initialValue: engine.settings.fontName)
        _tempLineHeight = State(initialValue: engine.settings.lineHeight)
        _tempParagraphSpacing = State(initialValue: engine.settings.paragraphSpacing)
        _tempHPadding = State(initialValue: engine.settings.horizontalPadding)
        _tempVPadding = State(initialValue: engine.settings.verticalPadding)
        _tempPageStyle = State(initialValue: engine.settings.pageTurnStyle)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Font Size
                Section("字号") {
                    HStack {
                        Button(action: { if tempFontSize > 12 { tempFontSize -= 2 } }) {
                            Image(systemName: "textformat.size.smaller")
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        Text("\(Int(tempFontSize))")
                            .font(.system(size: tempFontSize))
                            .frame(minWidth: 40)
                        Spacer()
                        
                        Button(action: { if tempFontSize < 36 { tempFontSize += 2 } }) {
                            Image(systemName: "textformat.size.larger")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Font
                Section("字体") {
                    ForEach(fontOptions, id: \.1) { label, name in
                        Button(action: { tempFontName = name }) {
                            HStack {
                                Text(label)
                                    .font(.custom(name, size: 16))
                                Spacer()
                                if tempFontName == name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // Line spacing
                Section("行间距") {
                    Slider(value: $tempLineHeight, in: 1.0...3.0, step: 0.1) {
                        Text("\(String(format: "%.1f", tempLineHeight))")
                    }
                }
                
                // Paragraph spacing
                Section("段落间距") {
                    Slider(value: $tempParagraphSpacing, in: 0...24, step: 2) {
                        Text("\(Int(tempParagraphSpacing))pt")
                    }
                }
                
                // Margins
                Section("边距") {
                    VStack {
                        HStack {
                            Text("左右")
                            Slider(value: $tempHPadding, in: 12...48, step: 4)
                            Text("\(Int(tempHPadding))")
                                .frame(width: 30)
                        }
                        HStack {
                            Text("上下")
                            Slider(value: $tempVPadding, in: 8...32, step: 4)
                            Text("\(Int(tempVPadding))")
                                .frame(width: 30)
                        }
                    }
                }
                
                // Background theme
                Section("阅读背景") {
                    ForEach(Array(ReaderTheme.themes.enumerated()), id: \.offset) { i, theme in
                        Button(action: {
                            selectedTheme = i
                            engine.settings.backgroundColor = theme.backgroundColor
                            engine.settings.textColor = theme.textColor
                        }) {
                            HStack {
                                Circle()
                                    .fill(Color(theme.backgroundColor))
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().stroke(Color.secondary.opacity(0.3)))
                                Text(theme.name)
                                    .padding(.leading, 8)
                                Spacer()
                                if engine.settings.backgroundColor == theme.backgroundColor {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // Page turn style
                Section("翻页方式") {
                    ForEach(PageTurnStyle.allCases, id: \.self) { style in
                        Button(action: { tempPageStyle = style }) {
                            HStack {
                                Text(style.label)
                                Spacer()
                                if tempPageStyle == style {
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
                    Button("应用") {
                        var s = engine.settings
                        s.fontSize = tempFontSize
                        s.fontName = tempFontName
                        s.lineHeight = tempLineHeight
                        s.paragraphSpacing = tempParagraphSpacing
                        s.horizontalPadding = tempHPadding
                        s.verticalPadding = tempVPadding
                        s.pageTurnStyle = tempPageStyle
                        engine.updateSettings(s)
                        onApply()
                        
                        if let data = try? JSONEncoder().encode(s) {
                            UserDefaults.standard.set(data, forKey: "reader_settings")
                        }
                        UserDefaults.standard.set(s.pageTurnStyle.rawValue, forKey: "page_turn_style")
                        
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
