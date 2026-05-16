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
    var rateLimitCountdown: Int? = nil

    private var countdownTask: Task<Void, Never>?

    // MARK: - 提案生成（5案）

    func generateSuggestions(pantryItems: [PantryItem]) async {
        isLoadingSuggestions = true
        errorMessage = nil
        suggestions = []

        do {
            let prompt = buildSuggestionPrompt(pantryItems: pantryItems)
            let raw = try await AIServiceFactory.make().send(prompt: prompt, maxOutputTokens: 512)
            suggestions = try parseMenuSuggestions(from: raw)
        } catch let e as GeminiError {
            errorMessage = e.errorDescription
            if case .rateLimited(let seconds, _) = e { startCountdown(seconds: seconds) }
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
            let raw = try await AIServiceFactory.make().send(prompt: prompt, maxOutputTokens: 1024)
            detailedRecipe = try parseDetailedRecipe(from: raw)
        } catch let e as GeminiError {
            errorMessage = e.errorDescription
            if case .rateLimited(let seconds, _) = e { startCountdown(seconds: seconds) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingRecipe = false
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
        家庭料理の献立を5つ提案してください。
        人数: \(servings)人分
        食材: \(allIngredients)
        必須食材: \(mustUseText)
        気分: \(moodText)

        以下のJSON配列**のみ**を返してください。
        [{"name":"料理名","description":"1〜2文の説明"}]
        要素は必ず5つ。
        """
    }

    private func buildRecipePrompt(dishName: String, pantryItems: [PantryItem]) -> String {
        return """
        「\(dishName)」の\(servings)人分のレシピを教えてください。
        以下のJSON**のみ**を返してください。前置きや説明文は不要です。
        {
          "name": "料理名",
          "ingredients": ["材料名（分量）"],
          "steps": ["手順1", "手順2"]
        }
        材料は10個以内、手順は6ステップ以内で簡潔にまとめてください。
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
