import Foundation
import GoogleGenerativeAI

enum GeminiError: LocalizedError {
    case invalidAPIKey
    case emptyResponse
    case rateLimited(retryAfter: Int, detail: String)
    case apiError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "APIキーが設定されていません。Sources/Secrets.swift を確認してください"
        case .emptyResponse:
            return "Gemini からの応答が空です"
        case .rateLimited(let seconds, let detail):
            let isBillingQuota = detail.lowercased().contains("billing") || detail.lowercased().contains("check your plan")
            let timeLabel = seconds >= 60 ? "\(seconds / 60)分\(seconds % 60)秒" : "\(seconds)秒"
            if isBillingQuota {
                return "無料クォータを使い切りました。\n日次上限（1,500回/日）超過の可能性があります。\n明日 UTC 0:00（日本時間 9:00）にリセットされます。\n詳細: \(detail.prefix(100))"
            }
            return "分間リクエスト上限（15回/分）に達しました。\n\(timeLabel)後に再試行できます。\n詳細: \(detail.prefix(100))"
        case .apiError(let message):
            return "Gemini APIエラー: \(message)"
        case .networkError(let e):
            return "通信エラー: \(e.localizedDescription)"
        }
    }
}

struct GeminiService: AIService {
    // デバッグ時は true にして API を使わずモックデータを返す
    static var isDebugMode = false

    // UserDefaults を優先し、未設定なら Secrets.swift にフォールバック
    static var effectiveAPIKey: String {
        let stored = (UserDefaults.standard.string(forKey: "geminiAPIKey") ?? "")
            .trimmingCharacters(in: .whitespaces)
        return stored.isEmpty ? Secrets.geminiAPIKey : stored
    }

    static var isAPIKeyConfigured: Bool {
        let key = effectiveAPIKey
        return !key.isEmpty && key != "YOUR_GEMINI_API_KEY_HERE"
    }

    static var selectedModelName: String {
        UserDefaults.standard.string(forKey: "selectedGeminiModel") ?? GeminiModel.flash25Lite.rawValue
    }

    func send(prompt: String, maxOutputTokens: Int = 1024) async throws -> String {
        if Self.isDebugMode {
            try? await Task.sleep(for: .milliseconds(400))
            return Self.mockJSON(for: prompt)
        }

        let apiKey = Self.effectiveAPIKey
        guard apiKey != "YOUR_GEMINI_API_KEY_HERE", !apiKey.isEmpty else {
            throw GeminiError.invalidAPIKey
        }

        let config = GenerationConfig(temperature: 0.9, maxOutputTokens: maxOutputTokens)
        let model = GenerativeModel(name: Self.selectedModelName, apiKey: apiKey, generationConfig: config)

        do {
            let response = try await model.generateContent(prompt)
            if let text = response.text, !text.isEmpty { return text }
            throw GeminiError.emptyResponse

        } catch let error as GenerateContentError {
            if case .responseStoppedEarly(_, let partial) = error,
               let text = partial.text, !text.isEmpty { return text }
            let desc = String(describing: error)
            if desc.contains("429") || desc.contains("resourceExhausted") {
                let (seconds, raw) = extractRetryInfo(from: desc)
                throw GeminiError.rateLimited(retryAfter: seconds, detail: raw)
            }
            throw GeminiError.apiError(desc)

        } catch let error as GeminiError {
            throw error
        } catch {
            throw GeminiError.networkError(error)
        }
    }

    // MARK: - モックデータ

    static func mockJSON(for prompt: String) -> String {
        if prompt.contains("JSON配列") || prompt.contains("5つ") {
            return mockSuggestionsJSON
        } else if prompt.contains("不足栄養素") {
            return mockNutritionJSON
        } else {
            return mockRecipeJSON
        }
    }

    private static let mockSuggestionsJSON = """
    [
      {"name":"チキンカレー","description":"スパイシーで香り豊かな本格カレー。ご飯との相性が抜群です。"},
      {"name":"トマトパスタ","description":"フレッシュトマトとバジルのシンプルなパスタ。さっぱりとした風味が絶品。"},
      {"name":"チャーハン","description":"卵とネギを使った香ばしい炒飯。短時間で作れる満足の一品。"},
      {"name":"鶏の唐揚げ定食","description":"ジューシーな唐揚げにご飯と味噌汁を添えた定番定食。"},
      {"name":"焼き餃子","description":"ニラと豚肉たっぷりの手作り餃子。パリッとした焼き目が食欲をそそります。"}
    ]
    """

    private static let mockRecipeJSON = """
    {
      "name": "チキンカレー",
      "ingredients": [
        "鶏もも肉 300g",
        "玉ねぎ 1個",
        "にんじん 1本",
        "じゃがいも 2個",
        "カレールウ 4皿分",
        "水 600ml",
        "サラダ油 大さじ1"
      ],
      "steps": [
        "鶏肉・野菜を一口大に切る",
        "鍋に油を熱し、玉ねぎを透き通るまで炒める",
        "鶏肉を加えて表面に火が通るまで炒める",
        "にんじんとじゃがいもを加え、水を注いで中火で15分煮る",
        "カレールウを割り入れ、溶かしながらさらに5分煮て完成"
      ]
    }
    """

    private static let mockNutritionJSON = """
    {
      "summary": "全体的に炭水化物と脂質の摂取が多く、ビタミン・ミネラルが不足しがちです。野菜や魚をもっと取り入れましょう。",
      "deficiencies": [
        {
          "nutrient": "ビタミンC",
          "reason": "野菜・果物の摂取が少ないため不足しています",
          "ingredients": ["ブロッコリー", "パプリカ", "キウイ"],
          "recipeExamples": [
            {"name": "ブロッコリーのサラダ", "description": "茹でブロッコリーとドレッシングで手軽に作れる副菜"},
            {"name": "パプリカの炒め物", "description": "彩り豊かでビタミンCたっぷりの一品"}
          ]
        },
        {
          "nutrient": "カルシウム",
          "reason": "乳製品や小魚の摂取が少ないため不足しています",
          "ingredients": ["牛乳", "チーズ", "小松菜"],
          "recipeExamples": [
            {"name": "小松菜のお浸し", "description": "カルシウム豊富な小松菜を使った和風副菜"},
            {"name": "チーズ入りオムレツ", "description": "朝食に手軽なカルシウム補給メニュー"}
          ]
        },
        {
          "nutrient": "食物繊維",
          "reason": "根菜や豆類の摂取が少ないため不足しています",
          "ingredients": ["ごぼう", "さつまいも", "大豆"],
          "recipeExamples": [
            {"name": "きんぴらごぼう", "description": "食物繊維たっぷりの定番和食"},
            {"name": "さつまいもの煮物", "description": "甘みのあるさつまいもをやさしく煮た一品"}
          ]
        }
      ]
    }
    """

    // MARK: - リトライ時間抽出

    private func extractRetryInfo(from text: String) -> (seconds: Int, raw: String) {
        let snippet: String
        if let msgRange = text.range(of: "message: \""),
           let endRange = text[msgRange.upperBound...].range(of: "\"") {
            snippet = String(text[msgRange.upperBound..<endRange.lowerBound])
        } else {
            snippet = String(text.prefix(200))
        }
        if let match = text.firstMatch(of: /retry in (\d+(?:\.\d+)?)s/),
           let secs = Double(match.output.1) {
            return (Int(secs.rounded(.up)) + 2, snippet)
        }
        return (300, snippet.isEmpty ? text.prefix(200).description : snippet)
    }
}
