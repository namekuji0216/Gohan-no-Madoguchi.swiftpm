import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    let viewModel: MealSuggestionViewModel
    let pantryItems: [PantryItem]

    @Environment(\.modelContext) private var modelContext
    @State private var rating = 3
    @State private var saved = false

    var body: some View {
        ScrollView {
            if viewModel.isLoadingRecipe {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("レシピを生成中…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else if let recipe = viewModel.detailedRecipe {
                VStack(alignment: .leading, spacing: 24) {
                    ingredientsSection(recipe.ingredients)
                    stepsSection(recipe.steps)
                    saveSection(recipe)
                }
                .padding()
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(viewModel.selectedSuggestion?.name ?? "レシピ")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - 材料

    private func ingredientsSection(_ ingredients: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("材料", systemImage: "list.bullet")
                .font(.headline)
            ForEach(ingredients, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("・")
                        .foregroundStyle(.secondary)
                    Text(item)
                }
                .font(.body)
            }
        }
    }

    // MARK: - 手順

    private func stepsSection(_ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("作り方", systemImage: "text.alignleft")
                .font(.headline)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(.accentColor, in: Circle())
                    Text(step)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - 保存

    private func saveSection(_ recipe: DetailedRecipe) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
            Label("評価して保存", systemImage: "star")
                .font(.headline)
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                        .onTapGesture { rating = star }
                }
            }
            Button {
                saveRecipe(recipe)
            } label: {
                Label(saved ? "保存済み" : "履歴に保存", systemImage: saved ? "checkmark" : "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(saved)
        }
    }

    private func saveRecipe(_ recipe: DetailedRecipe) {
        let history = RecipeHistory(
            name: recipe.name,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            rating: rating
        )
        modelContext.insert(history)
        saved = true
    }
}
