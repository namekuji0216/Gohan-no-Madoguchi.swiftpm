import SwiftUI
import SwiftData

struct MealSuggestionView: View {
    @Query private var pantryItems: [PantryItem]
    @State private var viewModel = MealSuggestionViewModel()
    @State private var showingRecipe = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    moodTagSection
                    keywordSection
                    generateButton
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }
                    suggestionsSection
                }
                .padding()
            }
            .navigationTitle("献立提案")
            .navigationDestination(isPresented: $showingRecipe) {
                if viewModel.selectedSuggestion != nil {
                    RecipeDetailView(viewModel: viewModel, pantryItems: pantryItems)
                }
            }
        }
    }

    // MARK: - 気分タグ

    private var moodTagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日の気分")
                .font(.headline)
            FlowLayout(spacing: 8) {
                ForEach(MoodTag.allCases) { tag in
                    MoodTagChip(
                        tag: tag,
                        isSelected: viewModel.selectedTags.contains(tag)
                    ) {
                        if viewModel.selectedTags.contains(tag) {
                            viewModel.selectedTags.remove(tag)
                        } else {
                            viewModel.selectedTags.insert(tag)
                        }
                    }
                }
            }
        }
    }

    // MARK: - キーワード入力

    private var keywordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("キーワード（任意）")
                .font(.headline)
            TextField("例：卵を使いたい、時短で…", text: $viewModel.keyword)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
        }
    }

    // MARK: - 生成ボタン

    private var generateButton: some View {
        Button {
            Task { await viewModel.generateSuggestions(pantryItems: pantryItems) }
        } label: {
            Label(
                viewModel.isLoadingSuggestions ? "提案を生成中…" : "献立を提案する",
                systemImage: "sparkles"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.isLoadingSuggestions)
    }

    // MARK: - 提案リスト

    @ViewBuilder
    private var suggestionsSection: some View {
        if viewModel.isLoadingSuggestions {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if !viewModel.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("提案されたメニュー")
                    .font(.headline)
                ForEach(viewModel.suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion) {
                        Task {
                            await viewModel.generateRecipe(for: suggestion, pantryItems: pantryItems)
                            showingRecipe = true
                        }
                    }
                }
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.gradient, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 気分タグチップ

private struct MoodTagChip: View {
    let tag: MoodTag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(tag.rawValue, systemImage: tag.icon)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.accentColor : Color(.systemGray5),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 提案カード

private struct SuggestionCard: View {
    let suggestion: MenuSuggestion
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(.body.bold())
                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - フローレイアウト（タグ折り返し）

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, width: proposal.width ?? 0).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: width, height: y + rowHeight), frames)
    }
}
