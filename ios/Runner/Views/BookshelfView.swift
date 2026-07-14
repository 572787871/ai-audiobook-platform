import SwiftUI
import UniformTypeIdentifiers

struct BookshelfView: View {
    @StateObject private var store = BookStore.shared
    @State private var showImporter = false
    @State private var showPasteSheet = false
    @State private var pasteText = ""
    @State private var importing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.96, green: 0.94, blue: 0.91).ignoresSafeArea()
                VStack(spacing: 0) {
                    // 顶部栏
                    HStack {
                        Text("书架")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                        if importing {
                            ProgressView()
                                .padding(.trailing, 16)
                        } else {
                            Button(action: { showImporter = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(.trailing, 8)
                        }
                        Button(action: {}) {
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
                                    BookCell(book: book)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationDestination(for: Book.self) { book in
                ReaderView(book: book)
            }
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
        .alert("导入失败", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
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

    private func importFile(_ url: URL) {
        importing = true
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let text = try TXTFileReader.readTextFile(url: url)
            let fileName = url.lastPathComponent
            let title = (fileName as NSString).deletingPathExtension
            let chapters = TXTChapterParser.parse(text)
            let bookId = UUID().uuidString
            let destDir = store.contentDir.appendingPathComponent(bookId)
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            let destURL = destDir.appendingPathComponent("original.txt")
            try text.write(to: destURL, atomically: true, encoding: .utf8)

            var book = Book(id: bookId, title: title, filePath: destURL.path,
                          fileSize: Int64(text.utf8.count))
            book.chapterCount = chapters.chapters.count
            store.save(book)
            importing = false
        } catch {
            errorMessage = error.localizedDescription
            importing = false
        }
    }
}

struct BookCell: View {
    let book: Book
    @State private var showMenu = false

    var body: some View {
        NavigationLink(value: book) {
            VStack(alignment: .leading, spacing: 4) {
                // 封面
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
                Button("继续阅读") {}
            }
            Button("从头阅读") {}
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
