import Foundation

@MainActor
final class BookStore: ObservableObject {
    static let shared = BookStore()

    @Published var books: [Book] = []

    private let fileManager = FileManager.default
    private var booksDir: URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("books", isDirectory: true)
    }

    private var indexURL: URL { booksDir.appendingPathComponent("index.json") }

    init() {
        try? fileManager.createDirectory(at: booksDir, withIntermediateDirectories: true)
        loadAll()
    }

    func loadAll() {
        guard let data = try? Data(contentsOf: indexURL),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            books = scanBooks()
            saveIndex()
            return
        }
        books = ids.compactMap { loadBook(id: $0) }
    }

    private func scanBooks() -> [Book] {
        guard let entries = try? fileManager.contentsOfDirectory(at: booksDir, sorting: .byCreationDate) else { return [] }
        return entries.compactMap { url -> Book? in
            guard url.hasDirectoryPath else { return nil }
            let bookURL = url.appendingPathComponent("book.json")
            guard let data = try? Data(contentsOf: bookURL),
                  var book = try? JSONDecoder().decode(Book.self, from: data) else { return nil }
            let original = url.appendingPathComponent("original.txt")
            if !fileManager.fileExists(atPath: original.path) { return nil }
            return book
        }
    }

    private func loadBook(id: String) -> Book? {
        let url = booksDir.appendingPathComponent(id).appendingPathComponent("book.json")
        guard let data = try? Data(contentsOf: url),
              let book = try? JSONDecoder().decode(Book.self, from: data) else { return nil }
        return book
    }

    func save(_ book: Book) {
        let dir = booksDir.appendingPathComponent(book.id)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("book.json")
        if let data = try? JSONEncoder().encode(book) {
            try? data.write(to: url)
        }
        if let idx = books.firstIndex(where: { $0.id == book.id }) {
            books[idx] = book
        } else {
            books.append(book)
        }
        saveIndex()
        objectWillChange.send()
    }

    func delete(id: String) {
        let dir = booksDir.appendingPathComponent(id)
        try? fileManager.removeItem(at: dir)
        books.removeAll { $0.id == id }
        saveIndex()
        objectWillChange.send()
    }

    private func saveIndex() {
        let ids = books.map(\.id)
        if let data = try? JSONEncoder().encode(ids) {
            try? data.write(to: indexURL)
        }
    }

    var contentDir: URL { booksDir }
}
