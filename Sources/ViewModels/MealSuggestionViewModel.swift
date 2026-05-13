import Foundation
import Observation

@Observable
final class MealSuggestionViewModel {
    var selectedTags: Set<MoodTag> = []
    var keyword = ""
    var suggestions: [MenuSuggestion] = []
    var selectedSuggestion: MenuSuggestion?
    var detailedRecipe: DetailedRecipe?
    var isLoadingSuggestions = false
    var isLoadingRecipe = false
    var errorMessage: String?

    private let service = AnthropicService()

    // MARK: - 提案生成

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
            let raw = try await service.send(prompt: prompt, maxTokens: 2048)
            detailedRecipe = try parseDetailedRecipe(from: raw)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingRecipe = false
    }

    // MARK: - プロンプト構築

    private func buildSuggestionPrompt(pantryItems: [PantryItem]) -> String {
        let ingredientList = pantryItems.isEmpty
            ? "（食材が登録されていません）"
            : pantryItems.map { "・\($0.name)（\($0.type.rawValue)）" }.joined(separator: "\n")

        let moodParts = selectedTags.map(\.rawValue) + (keyword.isEmpty ? [] : [keyword])
        let moodText = moodParts.isEmpty ? "特になし" : moodParts.joined(separator: "、")

        return """
        あなたは家庭料理の献立提案アシスタントです。
        以下の食材と気分を元に、今日の献立案を5つ提案してください。

        【冷蔵庫・パントリーの食材】
        \(ingredientList)

        【気分・食べたいもの】
        \(moodText)

        以下のJSON配列のみを返してください。説明文や前置きは不要です。
        [
          {"name": "料理名", "description": "料理の短い説明（1〜2文）"},
          ...
        ]
        """
    }

    private func buildRecipePrompt(dishName: String, pantryItems: [PantryItem]) -> String {
        let ingredientList = pantryItems.isEmpty
            ? "（食材が登録されていません）"
            : pantryItems.map { "・\($0.name)" }.joined(separator: "\n")

        return """
        「\(dishName)」の詳細なレシピを教えてください。

        【手元にある食材】
        \(ingredientList)

        手元にない食材があれば材料リストに含めてください。
        以下のJSONのみを返してください。説明文や前置きは不要です。
        {
          "name": "料理名",
          "ingredients": ["材料1（分量）", "材料2（分量）"],
          "steps": ["手順1", "手順2"]
        }
        """
    }

    // MARK: - レスポンスパース

    private func parseMenuSuggestions(from text: String) throws -> [MenuSuggestion] {
        let jsonString = extractJSON(from: text, kind: .array)
        guard let data = jsonString.data(using: .utf8) else {
            throw AnthropicError.decodingError("文字列変換失敗")
        }
        return try JSONDecoder().decode([MenuSuggestion].self, from: data)
    }

    private func parseDetailedRecipe(from text: String) throws -> DetailedRecipe {
        let jsonString = extractJSON(from: text, kind: .object)
        guard let data = jsonString.data(using: .utf8) else {
            throw AnthropicError.decodingError("文字列変換失敗")
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
