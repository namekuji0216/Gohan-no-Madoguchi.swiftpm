import SwiftUI
import SwiftData

@main
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PantryItem.self, RecipeHistory.self])
    }
}
