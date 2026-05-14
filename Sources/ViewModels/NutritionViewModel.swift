import Foundation
import Observation

@Observable
final class NutritionViewModel {
    var analysis: NutritionAnalysis?
    var isLoading = false
    var errorMessage: String?

    private let service = GeminiService()

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
            let raw = try await service.send(prompt: prompt)
            analysis = try parseAnalysis(from: raw)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - プロンプト構築

    private func buildPrompt(recipes: [RecipeHistory]) -> String {
        let recipeList = recipes.map { recipe in
            "・\(recipe.name)（材料: \(recipe.ingredients.joined(separator: "、"))）"
        }.joined(separator: "\n")

        return """
        あなたは管理栄養士です。以下の過去2週間の食事記録を分析し、不足している栄養素を特定してください。

        【過去2週間の料理記録】
        \(recipeList)

        以下のJSON**のみ**を返してください。前置きや説明文は不要です。
        {
          "summary": "食事全体の栄養バランスについての評価（2〜3文）",
          "deficiencies": [
            {
              "nutrient": "不足している栄養素名",
              "reason": "この栄養素が不足していると考えられる理由（1〜2文）",
              "ingredients": ["この栄養素を豊富に含む食材1", "食材2", "食材3", "食材4"],
              "recipeExamples": [
                {"name": "レシピ名", "description": "その料理の短い説明（1文）"},
                {"name": "レシピ名", "description": "その料理の短い説明（1文）"},
                {"name": "レシピ名", "description": "その料理の短い説明（1文）"}
              ]
            }
          ]
        }
        deficienciesは3〜5個、recipeExamplesは各栄養素につき3個にしてください。
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
