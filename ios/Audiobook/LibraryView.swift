import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
  enum Filter: String, CaseIterable { case all = "全部", reading = "阅读中", completed = "已完成" }

  @Environment(\.modelContext) private var context
  @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
  @State private var filter: Filter = .all
  @State private var importing = false
  @State private var searchText = ""
  @State private var pendingDelete: Book?
  @State private var importError: String?

  private var visibleBooks: [Book] {
    books.filter { book in
      let matchesSearch = searchText.isEmpty || book.title.localizedCaseInsensitiveContains(searchText)
      let matchesFilter = switch filter {
      case .all: true
      case .reading: book.progress > 0 && !book.isCompleted
      case .completed: book.isCompleted
      }
      return matchesSearch && matchesFilter
    }
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        filterBar
        if books.isEmpty { emptyState } else { shelf }
      }
      .background(Color(red: 0.98, green: 0.96, blue: 0.91))
      .navigationTitle("我的书架")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $searchText, prompt: "搜索书名")
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button { importing = true } label: { Image(systemName: "plus") }
          Menu {
            Button("导入 TXT / EPUB") { importing = true }
          } label: { Image(systemName: "ellipsis") }
        }
      }
      .fileImporter(
        isPresented: $importing,
        allowedContentTypes: [.item],
        allowsMultipleSelection: false
      ) { result in
        guard let url = try? result.get().first else { return }
        Task { await importBook(url) }
      }
      .alert("导入失败", isPresented: .constant(importError != nil)) {
        Button("好") { importError = nil }
      } message: { Text(importError ?? "") }
      .confirmationDialog("删除确认", isPresented: .constant(pendingDelete != nil), titleVisibility: .visible) {
        Button("删除", role: .destructive) {
          if let pendingDelete { context.delete(pendingDelete); try? context.save() }
          pendingDelete = nil
        }
        Button("取消", role: .cancel) { pendingDelete = nil }
      } message: { Text("确定删除《\(pendingDelete?.title ?? "")》吗？此操作不可撤销") }
    }
  }

  private var filterBar: some View {
    HStack(spacing: 28) {
      ForEach(Filter.allCases, id: \.self) { item in
        Button { filter = item } label: {
          VStack(spacing: 7) {
            Text("\(item.rawValue) \(count(for: item))").font(.subheadline)
            Rectangle().fill(filter == item ? Color.orange : .clear).frame(height: 2)
          }
        }.buttonStyle(.plain)
      }
      Spacer()
    }.padding(.horizontal, 20).padding(.top, 8)
  }

  private var shelf: some View {
    ScrollView {
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 22) {
        ForEach(visibleBooks) { book in
          NavigationLink { ReaderView(book: book) } label: { BookCoverView(book: book) }
            .buttonStyle(.plain)
            .contextMenu {
              Button("删除", role: .destructive) { pendingDelete = book }
            }
        }
      }.padding(18)
      Text("共 \(books.count) 本书").font(.footnote).foregroundStyle(.secondary).padding(.vertical, 18)
    }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("书架还是空的", systemImage: "books.vertical")
    } description: { Text("导入 TXT 或 EPUB 小说开始阅读") }
    actions: { Button("导入书籍") { importing = true }.buttonStyle(.borderedProminent).tint(.orange) }
  }

  private func count(for filter: Filter) -> Int {
    switch filter { case .all: books.count; case .reading: books.filter { $0.progress > 0 && !$0.isCompleted }.count; case .completed: books.filter(\.isCompleted).count }
  }

  @MainActor private func importBook(_ url: URL) async {
    // 从「文件」App 选来的 URL 是安全作用域资源，读取前需先访问；
    // fileImporter 多数情况下已授权、可直接读，因此访问失败时也不要拒绝。
    let accessed = url.startAccessingSecurityScopedResource()
    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
    do {
      let parsed = try BookImporter.importResult(.success(url))
      context.insert(Book(title: parsed.title, content: parsed.content, format: parsed.format))
      try context.save()
    } catch {
      importError = (error as? ImportError)?.errorDescription ?? error.localizedDescription
    }
  }
}

struct BookCoverView: View {
  let book: Book
  private var colors: [Color] {
    let sets: [[Color]] = [[.black, .brown], [.indigo, .black], [.teal, .black], [.blue, .gray], [.purple, .black]]
    return sets[book.coverSeed % sets.count]
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ZStack {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        Image(systemName: "mountain.2.fill").font(.system(size: 46)).foregroundStyle(.white.opacity(0.16)).offset(y: 36)
        Text(book.title).font(.headline).foregroundStyle(.white).multilineTextAlignment(.center).padding(10)
      }
      .aspectRatio(0.72, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 5))
      .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
      Text(book.title).font(.caption).fontWeight(.medium).lineLimit(1)
      Text(book.isCompleted ? "已完成" : String(format: "%.1f%%", book.progress * 100)).font(.caption2).foregroundStyle(.secondary)
    }
  }
}
