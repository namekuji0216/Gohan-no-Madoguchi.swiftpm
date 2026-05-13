import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            InventoryView()
                .tabItem {
                    Label("在庫管理", systemImage: "refrigerator")
                }
            MealSuggestionView()
                .tabItem {
                    Label("献立提案", systemImage: "fork.knife")
                }
            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "clock")
                }
        }
    }
}
