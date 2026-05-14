import Foundation
import GoogleGenerativeAI

enum GeminiError: LocalizedError {
    case invalidAPIKey
    case emptyResponse
    case rateLimited(retryAfter: Int)
    case apiError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "APIキーが設定されていません。Sources/Secrets.swift を確認してください"
        case .emptyResponse:
            return "Gemini からの応答が空です"
        case .rateLimited(let seconds):
            return "リクエスト上限に達しました（無料枠: 20回/分）。\(seconds)秒ほど待ってから再度お試しください"
        case .apiError(let message):
            return "Gemini APIエラー: \(message)"
        case .networkError(let e):
            return "通信エラー: \(e.localizedDescription)"
        }
    }
}

struct GeminiService {
    private let model: GenerativeModel

    init(apiKey: String = Secrets.geminiAPIKey, modelName: String = "gemini-2.5-flash") {
        let config = GenerationConfig(temperature: 0.9, maxOutputTokens: 8192)
        model = GenerativeModel(name: modelName, apiKey: apiKey, generationConfig: config)
    }

    func send(prompt: String) async throws -> String {
        guard Secrets.geminiAPIKey != "YOUR_GEMINI_API_KEY_HERE",
              !Secrets.geminiAPIKey.isEmpty else {
            throw GeminiError.invalidAPIKey
        }
        return try await attempt(prompt: prompt, retriesLeft: 1)
    }

    // MARK: - リトライ付き送信

    private func attempt(prompt: String, retriesLeft: Int) async throws -> String {
        do {
            let response = try await model.generateContent(prompt)

            if let text = response.text, !text.isEmpty {
                return text
            }
            throw GeminiError.emptyResponse

        } catch let error as GenerateContentError {
            // レスポンス途中停止 → 部分テキストを返す
            if case .responseStoppedEarly(_, let partial) = error,
               let text = partial.text, !text.isEmpty {
                return text
            }

            // 429 レート制限 → 待機してリトライ
            let desc = String(describing: error)
            if (desc.contains("429") || desc.contains("resourceExhausted")), retriesLeft > 0 {
                let wait = extractRetryDelay(from: desc)
                try await Task.sleep(for: .seconds(Double(wait)))
                return try await attempt(prompt: prompt, retriesLeft: retriesLeft - 1)
            }

            if desc.contains("429") || desc.contains("resourceExhausted") {
                throw GeminiError.rateLimited(retryAfter: extractRetryDelay(from: desc))
            }
            throw GeminiError.apiError(desc)

        } catch let error as GeminiError {
            throw error
        } catch {
            throw GeminiError.networkError(error)
        }
    }

    // MARK: - 待機秒数を抽出

    private func extractRetryDelay(from text: String) -> Int {
        // "Please retry in 42.066s" のような文字列から秒数を取得
        if let match = text.firstMatch(of: /retry in (\d+(?:\.\d+)?)s/),
           let seconds = Double(match.output.1) {
            return Int(seconds.rounded(.up)) + 2  // 余裕を持たせる
        }
        return 62  // デフォルト: 62秒
    }
}
