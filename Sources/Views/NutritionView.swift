import SwiftUI
import SwiftData

struct NutritionView: View {
    @Query(sort: \RecipeHistory.createdAt, order: .reverse) private var allRecipes: [RecipeHistory]
    @State private var viewModel = NutritionViewModel()
    @AppStorage("geminiAPIKey") private var savedAPIKey = ""

    private var isAPIKeyConfigured: Bool { GeminiService.isAPIKeyConfigured }

    private var recentRecipes: [RecipeHistory] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now)!
        return allRecipes.filter { $0.createdAt >= cutoff }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    recipeCountBanner
                    analyzeButton

                    if viewModel.isLoading {
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorBanner(error)
                    } else if let analysis = viewModel.analysis {
                        analysisResult(analysis)
                    }
                }
                .padding()
            }
            .navigationTitle("栄養分析")
        }
    }

    // MARK: - 過去2週間のレシピ数バナー

    private var recipeCountBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("過去2週間の記録")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(recentRecipes.count) レシピ")
                    .font(.title3.bold())
            }
            Spacer()
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 分析ボタン

    private var analyzeButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await viewModel.analyze(recipes: recentRecipes) }
            } label: {
                Group {
                    if let countdown = viewModel.rateLimitCountdown {
                        Label("\(countdown)秒後に再試行できます", systemImage: "clock")
                    } else if viewModel.isLoading {
                        Label("分析中…", systemImage: "waveform.path.ecg")
                    } else {
                        Label("栄養バランスを分析する", systemImage: "waveform.path.ecg")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isAPIKeyConfigured || viewModel.isLoading || viewModel.rateLimitCountdown != nil)

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

    // MARK: - ローディング

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("食事記録を分析中です…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: - エラー

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.gradient, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 分析結果

    @ViewBuilder
    private func analysisResult(_ analysis: NutritionAnalysis) -> some View {
        // サマリー
        VStack(alignment: .leading, spacing: 8) {
            Label("総合評価", systemImage: "chart.bar.doc.horizontal")
                .font(.headline)
            Text(analysis.summary)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))

        // 不足栄養素カード
        VStack(alignment: .leading, spacing: 12) {
            Text("不足している栄養素")
                .font(.headline)
            ForEach(analysis.deficiencies) { def in
                DeficiencyCard(deficiency: def)
            }
        }
    }
}

// MARK: - 不足栄養素カード

private struct DeficiencyCard: View {
    let deficiency: NutritionAnalysis.Deficiency
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー（タップで展開）
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deficiency.nutrient)
                            .font(.body.bold())
                            .foregroundStyle(.primary)
                        Text(deficiency.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal)

                VStack(alignment: .leading, spacing: 14) {
                    // 含まれる食材
                    VStack(alignment: .leading, spacing: 8) {
                        Label("含まれる食材", systemImage: "leaf")
                            .font(.subheadline.bold())
                        FlowLayout(spacing: 6) {
                            ForEach(deficiency.ingredients, id: \.self) { ing in
                                Text(ing)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5), in: Capsule())
                            }
                        }
                    }

                    // レシピ例
                    VStack(alignment: .leading, spacing: 8) {
                        Label("おすすめレシピ", systemImage: "fork.knife")
                            .font(.subheadline.bold())
                        ForEach(deficiency.recipeExamples) { example in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5))
                                    .padding(.top, 6)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(example.name)
                                        .font(.subheadline.bold())
                                    Text(example.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
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
        for (i, frame) in result.frames.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                              proposal: .unspecified)
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            frames.append(CGRect(origin: .init(x: x, y: y), size: size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return (CGSize(width: width, height: y + rowH), frames)
    }
}
