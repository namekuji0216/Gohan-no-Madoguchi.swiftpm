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
            NutritionView()
                .tabItem {
                    Label("栄養分析", systemImage: "heart.text.clipboard")
                }
            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "clock")
                }
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
        }
    }
}
