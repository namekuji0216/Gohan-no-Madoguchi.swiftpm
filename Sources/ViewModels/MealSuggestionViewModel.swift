import Foundation
import Observation

@Observable
final class MealSuggestionViewModel {
    var selectedTags: Set<MoodTag> = []
    var keyword = ""
    var servings: Int = 2
    var selectedIngredientNames: Set<String> = []
    var suggestions: [MenuSuggestion] = []
    var selectedSuggestion: MenuSuggestion?
    var detailedRecipe: DetailedRecipe?
    var isLoadingSuggestions = false
    var isLoadingRecipe = false
    var errorMessage: String?

    private let service = GeminiService()

    // MARK: - 提案生成（5案）

    func generateSuggestions(pantryItems: [PantryItem]) async {
        isLoadingSuggestions = true
        errorMessage = nil
        suggestions = []

        do {
            let prompt = buildSuggestionPrompt(pantryItems: pantryItems)
            let raw = try await service.send(prompt: prompt)
            suggestions = try parseMenuSuggestions(from: raw)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingSuggestions = false
    }

    // MARK: - レシピ詳細生成

    func generateRecipe(for suggestion: MenuSuggestion, pantryItems: [PantryItem]) async {
        selectedSuggestion = suggestion
        detailedRecipe = nil
        isLoadingRecipe = true
        errorMessage = nil

        do {
            let prompt = buildRecipePrompt(dishName: suggestion.name, pantryItems: pantryItems)
            let raw = try await service.send(prompt: prompt)
            detailedRecipe = try parseDetailedRecipe(from: raw)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingRecipe = false
    }

    // MARK: - プロンプト構築

    private func buildSuggestionPrompt(pantryItems: [PantryItem]) -> String {
        let allIngredients = pantryItems.isEmpty
            ? "（食材が登録されていません）"
            : pantryItems.map { "・\($0.name)（\($0.type.rawValue)）" }.joined(separator: "\n")

        let mustUseText: String
        if selectedIngredientNames.isEmpty {
            mustUseText = "特になし"
        } else {
            mustUseText = selectedIngredientNames.sorted().map { "・\($0)" }.joined(separator: "\n")
        }

        let moodParts = selectedTags.map(\.rawValue) + (keyword.isEmpty ? [] : [keyword])
        let moodText = moodParts.isEmpty ? "特になし" : moodParts.joined(separator: "、")

        return """
        あなたは家庭料理の献立提案アシスタントです。
        以下の条件をもとに、献立案を**5つ**提案してください。

        【人数】
        \(servings)人分

        【冷蔵庫・パントリーの食材】
        \(allIngredients)

        【必ず使いたい食材】
        \(mustUseText)

        【気分・食べたいもの】
        \(moodText)

        以下のJSON配列**のみ**を返してください。前置きや説明文は不要です。
        [
          {
            "name": "料理名（日本語）",
            "description": "その料理の短い説明（1〜2文、食欲をそそる表現で）"
          }
        ]
        要素は必ず5つにしてください。
        """
    }

    private func buildRecipePrompt(dishName: String, pantryItems: [PantryItem]) -> String {
        let ingredientList = pantryItems.isEmpty
            ? "（食材が登録されていません）"
            : pantryItems.map { "・\($0.name)" }.joined(separator: "\n")

        return """
        「\(dishName)」の\(servings)人分の詳細なレシピを教えてください。

        【手元にある食材】
        \(ingredientList)

        手元にない食材も材料リストに含めてください（買い物の参考にします）。
        以下のJSON**のみ**を返してください。前置きや説明文は不要です。
        {
          "name": "料理名",
          "ingredients": [
            "材料名（分量）",
            "材料名（分量）"
          ],
          "steps": [
            "手順1の説明",
            "手順2の説明"
          ]
        }
        """
    }

    // MARK: - レスポンスパース

    private func parseMenuSuggestions(from text: String) throws -> [MenuSuggestion] {
        let json = extractJSON(from: text, kind: .array)
        guard let data = json.data(using: .utf8) else {
            throw GeminiError.emptyResponse
        }
        return try JSONDecoder().decode([MenuSuggestion].self, from: data)
    }

    private func parseDetailedRecipe(from text: String) throws -> DetailedRecipe {
        let json = extractJSON(from: text, kind: .object)
        guard let data = json.data(using: .utf8) else {
            throw GeminiError.emptyResponse
        }
        return try JSONDecoder().decode(DetailedRecipe.self, from: data)
    }

    private enum JSONKind { case array, object }

    private func extractJSON(from text: String, kind: JSONKind) -> String {
        let open: Character  = kind == .array ? "[" : "{"
        let close: Character = kind == .array ? "]" : "}"
        guard let start = text.firstIndex(of: open),
              let end   = text.lastIndex(of: close) else { return text }
        return String(text[start...end])
    }
}
