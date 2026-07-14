import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct BookshelfView: View {
    @StateObject private var store = BookStore.shared
    @State private var showImporter = false
    @State private var showPasteSheet = false
    @State private var pasteText = ""
    @State private var pasteTitle = ""
    @State private var importing = false
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var showActionSheet = false
    @State private var navigateToBook: Book?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.96, green: 0.94, blue: 0.91).ignoresSafeArea()
                VStack(spacing: 0) {
                    // Top bar
                    HStack {
                        Text("书架")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                        if importing {
                            ProgressView()
                                .padding(.trailing, 16)
                        } else {
                            Button(action: { showActionSheet = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(.trailing, 8)
                        }
                        Button(action: { showSettings = true }) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    if store.books.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 20) {
                                ForEach(store.books.sorted(by: { ($0.lastReadAt ?? $0.createdAt) > ($1.lastReadAt ?? $1.createdAt) })) { book in
                                    BookCell(book: book, onNavigate: { navigateToBook = book })
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationDestination(item: $navigateToBook) { book in
                ReaderView(book: book)
            }
        }
        .confirmationDialog("导入书籍", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("从文件导入") { showImporter = true }
            Button("粘贴文本") { showPasteSheet = true }
            Button("取消", role: .cancel) {}
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.plainText, .init(filenameExtension: "txt") ?? .plainText],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importFile(url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("粘贴导入", isPresented: $showPasteSheet) {
            TextField("书名（可选）", text: $pasteTitle)
            TextField("粘贴小说内容", text: $pasteText, axis: .vertical)
            Button("导入") {
                guard !pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    errorMessage = "内容不能为空"
                    return
                }
                importText(pasteText, title: pasteTitle)
                pasteText = ""
                pasteTitle = ""
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("输入或粘贴小说内容，支持自动分章")
        }
        .alert("导入失败", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 100)
            Image(systemName: "book")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.4))
            Text("暂无书籍")
                .font(.title2.weight(.semibold))
            Text("点击右上角\"＋\"导入第一本小说")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button(action: { showImporter = true }) {
                Text("导入书籍")
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Import File
    private func importFile(_ url: URL) {
        importing = true
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let encoding = TXTFileReader.detectEncoding(from: data)
            guard let text = String(data: data, encoding: encoding) else {
                throw TXTError.cannotDecode(encoding: encoding.debugDescription)
            }
            let fileName = url.lastPathComponent
            let title = (fileName as NSString).deletingPathExtension
            let chapterList = TXTChapterParser.parse(text)
            let bookId = UUID().uuidString
            let destDir = store.contentDir.appendingPathComponent(bookId)
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            let destURL = destDir.appendingPathComponent("original.txt")
            try text.write(to: destURL, atomically: true, encoding: .utf8)

            var book = Book(id: bookId, title: title, filePath: destURL.path,
                          fileSize: Int64(data.count), encoding: encoding.description)
            book.chapterCount = chapterList.chapters.count
            book.chapters = chapterList.chapters.map { Chapter(index: $0.index, title: $0.title, startOffset: $0.startOffset, endOffset: $0.endOffset) }
            store.save(book)
            importing = false
            navigateToBook = book
        } catch {
            errorMessage = error.localizedDescription
            importing = false
        }
    }

    // MARK: - Import Paste Text
    private func importText(_ text: String, title: String? = nil) {
        importing = true
        let bookId = UUID().uuidString
        let destDir = store.contentDir.appendingPathComponent(bookId)
        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            let destURL = destDir.appendingPathComponent("original.txt")
            try text.write(to: destURL, atomically: true, encoding: .utf8)

            let chapterList = TXTChapterParser.parse(text)
            let bookTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? title!.trimmingCharacters(in: .whitespacesAndNewlines)
                : "未命名书籍"

            var book = Book(id: bookId, title: bookTitle, filePath: destURL.path,
                          fileSize: Int64(text.utf8.count), encoding: "UTF-8")
            book.chapterCount = chapterList.chapters.count
            book.chapters = chapterList.chapters.map { Chapter(index: $0.index, title: $0.title, startOffset: $0.startOffset, endOffset: $0.endOffset) }
            store.save(book)
            importing = false
            navigateToBook = book
        } catch {
            errorMessage = error.localizedDescription
            importing = false
        }
    }
}

// MARK: - Book Cell
struct BookCell: View {
    let book: Book
    let onNavigate: () -> Void
    @State private var showMenu = false

    var body: some View {
        Button(action: onNavigate) {
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(coverGradient)
                        .aspectRatio(2/3, contentMode: .fit)
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    Text(book.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .lineLimit(4)
                }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 3)
                }
                .onLongPressGesture { showMenu = true }

                Text(book.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let chapter = book.lastReadChapter, !chapter.isEmpty {
                    Text(chapter)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text(progressLabel)
                    .font(.system(size: 11))
                    .foregroundColor(book.isCompleted ? .blue : .secondary)
            }
        }
        .buttonStyle(.plain)
        .confirmationDialog(book.title, isPresented: $showMenu) {
            if book.readingProgress > 0 {
                Button("继续阅读") { onNavigate() }
            }
            Button("从头阅读") {
                var b = book
                b.lastReadOffset = 0
                b.chapterIndex = 0
                b.pageIndex = 0
                b.readingProgress = 0
                BookStore.shared.save(b)
                onNavigate()
            }
            Button("书籍详情") { onNavigate() }
            Button("标记为已完成") {
                var b = book
                b.isCompleted = true
                b.readingProgress = 1.0
                BookStore.shared.save(b)
            }
            Button("删除书籍", role: .destructive) {
                BookStore.shared.delete(id: book.id)
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var coverGradient: LinearGradient {
        let colors: [Color] = [
            [.blue, .purple], [.pink, .red], [.green, .teal],
            [.orange, .brown], [.purple, .indigo], [.cyan, .blue],
            [.yellow, .orange], [.green, .mint], [.pink, .purple], [.teal, .blue]
        ]
        let idx = abs(book.id.hash) % colors.count
        return LinearGradient(colors: colors[idx], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var progressLabel: String {
        let pct = Int(book.readingProgress * 100)
        if book.readingProgress <= 0 { return "未开始" }
        if pct >= 100 || book.isCompleted { return "已完成" }
        return "已读 \(pct)%"
    }
}

// MARK: - TXT Error
enum TXTError: Error, LocalizedError {
    case cannotDecode(encoding: String)
    
    var errorDescription: String? {
        switch self {
        case .cannotDecode(let enc):
            return "无法解码文件，编码：\(enc)"
        }
    }
}

// MARK: - Settings View (placeholder)
struct SettingsView: View {
    @State private var defaultFontSize: CGFloat = 20
    @State private var defaultFontName = "PingFang SC"
    @State private var defaultPageStyle = PageTurnStyle.curl
    @Environment(\.dismiss) private var dismiss
    
    private let fontOptions = [
        ("苹方", "PingFang SC"),
        ("宋体", "STSongti-SC-Regular"),
        ("黑体", "STHeitiSC-Light"),
        ("楷体", "STKaitiSC-Regular"),
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("阅读设置") {
                    NavigationLink("默认字体和字号") {
                        Form {
                            Picker("字体", selection: $defaultFontName) {
                                ForEach(fontOptions, id: \.1) { label, name in
                                    Text(label).tag(name)
                                }
                            }
                            Stepper("字号：\(Int(defaultFontSize))", value: $defaultFontSize, in: 12...36, step: 2)
                        }
                        .navigationTitle("字体和字号")
                    }
                    
                    Picker("默认翻页方式", selection: $defaultPageStyle) {
                        ForEach(PageTurnStyle.allCases, id: \.self) { style in
                            Text(style.label).tag(style)
                        }
                    }
                }
                
                Section("存储") {
                    Button("清除缓存") {
                        let cache = URLCache.shared
                        cache.removeAllCachedResponses()
                    }
                }
                
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        // Save defaults
                        UserDefaults.standard.set(defaultFontName, forKey: "default_font")
                        UserDefaults.standard.set(defaultFontSize, forKey: "default_font_size")
                        UserDefaults.standard.set(defaultPageStyle.rawValue, forKey: "page_turn_style")
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            defaultFontName = UserDefaults.standard.string(forKey: "default_font") ?? "PingFang SC"
            defaultFontSize = UserDefaults.standard.object(forKey: "default_font_size") as? CGFloat ?? 20
            if let raw = UserDefaults.standard.string(forKey: "page_turn_style"),
               let style = PageTurnStyle(rawValue: raw) {
                defaultPageStyle = style
            }
        }
    }
}
