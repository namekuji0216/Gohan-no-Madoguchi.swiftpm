import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \RecipeHistory.createdAt, order: .reverse)
    private var recipes: [RecipeHistory]

    var body: some View {
        NavigationStack {
            List(recipes) { recipe in
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.body)
                    HStack {
                        Text(String(repeating: "★", count: recipe.rating))
                            .foregroundStyle(.yellow)
                        Text(recipe.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("履歴")
            .overlay {
                if recipes.isEmpty {
                    ContentUnavailableView("履歴がありません", systemImage: "clock")
                }
            }
        }
    }
}
