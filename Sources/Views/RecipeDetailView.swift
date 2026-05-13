import SwiftUI
import SwiftData
import PhotosUI

struct RecipeDetailView: View {
    let viewModel: MealSuggestionViewModel
    let pantryItems: [PantryItem]

    @Environment(\.modelContext) private var modelContext
    @State private var rating = 3
    @State private var saved = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?

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
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self),
                      let ui = UIImage(data: data),
                      let jpeg = ui.jpegData(compressionQuality: 0.7) else { return }
                photoData = jpeg
            }
        }
    }

    // MARK: - 材料

    private func ingredientsSection(_ ingredients: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("材料", systemImage: "list.bullet")
                .font(.headline)
            ForEach(ingredients, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("・").foregroundStyle(.secondary)
                    Text(item)
                }
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
                        .background(.tint, in: Circle())
                    Text(step)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - 保存

    private func saveSection(_ recipe: DetailedRecipe) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            // 写真
            Label("写真（任意）", systemImage: "photo")
                .font(.headline)

            if let data = photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(photoData == nil ? "写真を追加" : "写真を変更", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            // 評価
            Label("評価", systemImage: "star")
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
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(saved)
        }
    }

    private func saveRecipe(_ recipe: DetailedRecipe) {
        let history = RecipeHistory(
            name: recipe.name,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            rating: rating,
            photoData: photoData
        )
        modelContext.insert(history)
        saved = true
    }
}
