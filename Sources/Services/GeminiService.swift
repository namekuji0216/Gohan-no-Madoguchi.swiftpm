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
            return "リクエスト上限（無料枠: 15回/分）に達しました。\(seconds)秒後にもう一度お試しください"
        case .apiError(let message):
            return "Gemini APIエラー: \(message)"
        case .networkError(let e):
            return "通信エラー: \(e.localizedDescription)"
        }
    }
}

struct GeminiService {
    // gemini-2.0-flash: 思考トークンなし・無料枠でトークン消費が少ない
    private static let modelName = "gemini-2.0-flash"
    private let apiKey: String

    init(apiKey: String = Secrets.geminiAPIKey) {
        self.apiKey = apiKey
    }

    /// maxOutputTokens を呼び出し側で指定してトークン消費を最小化する
    func send(prompt: String, maxOutputTokens: Int = 1024) async throws -> String {
        guard apiKey != "YOUR_GEMINI_API_KEY_HERE", !apiKey.isEmpty else {
            throw GeminiError.invalidAPIKey
        }

        let config = GenerationConfig(temperature: 0.9, maxOutputTokens: maxOutputTokens)
        let model = GenerativeModel(
            name: Self.modelName,
            apiKey: apiKey,
            generationConfig: config
        )

        do {
            let response = try await model.generateContent(prompt)

            if let text = response.text, !text.isEmpty { return text }
            throw GeminiError.emptyResponse

        } catch let error as GenerateContentError {
            if case .responseStoppedEarly(_, let partial) = error,
               let text = partial.text, !text.isEmpty { return text }

            let desc = String(describing: error)
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

    private func extractRetryDelay(from text: String) -> Int {
        if let match = text.firstMatch(of: /retry in (\d+(?:\.\d+)?)s/),
           let seconds = Double(match.output.1) {
            return Int(seconds.rounded(.up)) + 2
        }
        return 62
    }
}
