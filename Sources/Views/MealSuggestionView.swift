import SwiftUI
import SwiftData

struct MealSuggestionView: View {
    @Query(sort: \PantryItem.registeredAt) private var pantryItems: [PantryItem]
    @State private var viewModel = MealSuggestionViewModel()
    @State private var showingRecipe = false
    @AppStorage("geminiAPIKey")       private var geminiKey = ""
    @AppStorage("groqAPIKey")         private var groqKey = ""
    @AppStorage("selectedAIProvider") private var selectedProvider = ""

    private var isAPIKeyConfigured: Bool { AIServiceFactory.isAPIKeyConfigured }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    servingsSection
                    moodTagSection
                    ingredientPickerSection
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
            .onChange(of: showingRecipe) { _, isShowing in
                if !isShowing { viewModel.clearRecipe() }
            }
        }
    }

    // MARK: - 人数

    private var servingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("人数")
                .font(.headline)
            HStack(spacing: 16) {
                Button {
                    if viewModel.servings > 1 { viewModel.servings -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.servings > 1 ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                }
                .buttonStyle(.plain)

                Text("\(viewModel.servings)人分")
                    .font(.title3.bold())
                    .frame(minWidth: 60, alignment: .center)

                Button {
                    if viewModel.servings < 8 { viewModel.servings += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.servings < 8 ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                }
                .buttonStyle(.plain)
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

    // MARK: - 使いたい食材

    @ViewBuilder
    private var ingredientPickerSection: some View {
        if !pantryItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("使いたい食材（任意）")
                            .font(.headline)
                        Text("選択した食材を優先して献立に使います")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !viewModel.selectedIngredientNames.isEmpty {
                        Button("クリア") {
                            viewModel.selectedIngredientNames.removeAll()
                        }
                        .font(.caption)
                    }
                }

                ForEach(PantryItemType.allCases.filter { $0 != .seasoning }, id: \.self) { type in
                    let group = pantryItems.filter { $0.type == type }
                    if !group.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(type.rawValue, systemImage: type.icon)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            FlowLayout(spacing: 8) {
                                ForEach(group) { item in
                                    let selected = viewModel.selectedIngredientNames.contains(item.name)
                                    IngredientChip(name: item.name, isSelected: selected) {
                                        if selected {
                                            viewModel.selectedIngredientNames.remove(item.name)
                                        } else {
                                            viewModel.selectedIngredientNames.insert(item.name)
                                        }
                                    }
                                }
                            }
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
        VStack(spacing: 8) {
            Button {
                Task { await viewModel.generateSuggestions(pantryItems: pantryItems) }
            } label: {
                Group {
                    if let countdown = viewModel.rateLimitCountdown {
                        Label("\(countdown)秒後に再試行できます", systemImage: "clock")
                    } else if viewModel.isLoadingSuggestions {
                        Label("提案を生成中…", systemImage: "sparkles")
                    } else {
                        Label("献立を提案する", systemImage: "sparkles")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isAPIKeyConfigured || viewModel.isLoadingSuggestions || viewModel.rateLimitCountdown != nil)

            if !isAPIKeyConfigured {
                Label("設定画面から Gemini API キーを登録してください", systemImage: "key")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            } else if viewModel.rateLimitCountdown != nil {
                Text("上限に達しました。カウントダウン後に再試行できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - 提案リスト

    @ViewBuilder
    private var suggestionsSection: some View {
        if viewModel.isLoadingSuggestions {
            HStack { Spacer(); ProgressView(); Spacer() }
        } else if !viewModel.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("提案されたメニュー")
                    .font(.headline)
                ForEach(viewModel.suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion) {
                        Task {
                            await viewModel.generateRecipe(for: suggestion, pantryItems: pantryItems)
                            if viewModel.detailedRecipe != nil {
                                showingRecipe = true
                            }
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
                    isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.systemGray5)),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 食材チップ

private struct IngredientChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                }
                Text(name)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.systemGray5)),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
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
                    .foregroundStyle(.tint)
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

// MARK: - フローレイアウト

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, width: proposal.width ?? 0).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: .unspecified
            )
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
