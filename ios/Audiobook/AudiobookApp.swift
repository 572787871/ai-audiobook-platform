import SwiftData
import SwiftUI

@main
struct AudiobookApp: App {
  private let container: ModelContainer = {
    let schema = Schema([Book.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    return try! ModelContainer(for: schema, configurations: [configuration])
  }()

  var body: some Scene {
    WindowGroup {
      LibraryView()
        .preferredColorScheme(.light)
    }
    .modelContainer(container)
  }
}
