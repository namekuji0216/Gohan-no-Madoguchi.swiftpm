import Foundation
import Observation

@Observable
final class NutritionViewModel {
    var analysis: NutritionAnalysis?
    var isLoading = false
    var errorMessage: String?
    var rateLimitCountdown: Int? = nil

    private var countdownTask: Task<Void, Never>?

    func analyze(recipes: [RecipeHistory]) async {
        guard !recipes.isEmpty else {
            errorMessage = "過去2週間に登録されたレシピがありません。\n献立提案でレシピを保存してから分析してください。"
            return
        }

        isLoading = true
        errorMessage = nil
        analysis = nil

        do {
            let prompt = buildPrompt(recipes: recipes)
            let raw = try await AIServiceFactory.make().send(prompt: prompt, maxOutputTokens: 1024)
            analysis = try parseAnalysis(from: raw)
        } catch let e as GeminiError {
            errorMessage = e.errorDescription
            if case .rateLimited(let seconds, _) = e { startCountdown(seconds: seconds) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - カウントダウン

    private func startCountdown(seconds: Int) {
        countdownTask?.cancel()
        rateLimitCountdown = seconds
        countdownTask = Task { @MainActor in
            for remaining in stride(from: seconds - 1, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                rateLimitCountdown = remaining
            }
            rateLimitCountdown = nil
        }
    }

    // MARK: - プロンプト構築

    private func buildPrompt(recipes: [RecipeHistory]) -> String {
        let recipeList = recipes.map { recipe in
            "・\(recipe.name)（材料: \(recipe.ingredients.joined(separator: "、"))）"
        }.joined(separator: "\n")

        return """
        管理栄養士として、以下の食事記録から不足栄養素を分析してください。
        \(recipeList)

        以下のJSON**のみ**を返してください。
        {"summary":"2文の総合評価","deficiencies":[{"nutrient":"栄養素名","reason":"1文の理由","ingredients":["食材1","食材2","食材3"],"recipeExamples":[{"name":"レシピ名","description":"1文"},{"name":"レシピ名","description":"1文"}]}]}
        deficienciesは3個、recipeExamplesは各2個にしてください。
        """
    }

    // MARK: - パース

    private func parseAnalysis(from text: String) throws -> NutritionAnalysis {
        let json = extractJSON(from: text)
        guard let data = json.data(using: .utf8) else {
            throw GeminiError.emptyResponse
        }
        return try JSONDecoder().decode(NutritionAnalysis.self, from: data)
    }

    private func extractJSON(from text: String) -> String {
        guard let start = text.firstIndex(of: "{"),
              let end   = text.lastIndex(of: "}") else { return text }
        return String(text[start...end])
    }
}
