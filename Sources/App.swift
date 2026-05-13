import SwiftUI
import SwiftData

@main
struct TestApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([PantryItem.self, RecipeHistory.self])
        do {
            container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema)
            )
        } catch {
            // スキーマ変更などで既存ストアが読めない場合はインメモリで起動
            print("⚠️ ModelContainer init failed, falling back to in-memory: \(error)")
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
