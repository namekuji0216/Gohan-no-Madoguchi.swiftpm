import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \RecipeHistory.createdAt, order: .reverse) private var recipes: [RecipeHistory]
    @Environment(\.modelContext) private var modelContext

    private var groupedByRating: [(rating: Int, items: [RecipeHistory])] {
        let dict = Dictionary(grouping: recipes) { $0.rating }
        return (1...5).reversed().compactMap { rating in
            guard let items = dict[rating], !items.isEmpty else { return nil }
            return (rating: rating, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByRating, id: \.rating) { group in
                    Section(header: ratingHeader(group.rating)) {
                        ForEach(group.items) { recipe in
                            NavigationLink(destination: HistoryDetailView(recipe: recipe)) {
                                HistoryRow(recipe: recipe)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(group.items[i]) }
                        }
                    }
                }
            }
            .navigationTitle("履歴")
            .toolbar {
                if !recipes.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                }
            }
            .overlay {
                if recipes.isEmpty {
                    ContentUnavailableView("履歴がありません", systemImage: "clock")
                }
            }
        }
    }

    private func ratingHeader(_ rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }
        }
    }
}

private struct HistoryRow: View {
    let recipe: RecipeHistory

    var body: some View {
        HStack(spacing: 12) {
            if let data = recipe.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.secondary)
                    }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.body)
                Text(recipe.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
