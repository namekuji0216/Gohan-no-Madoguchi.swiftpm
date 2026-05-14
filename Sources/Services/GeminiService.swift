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
            let timeLabel: String
            if seconds >= 3600 {
                timeLabel = "\(seconds / 3600)時間\((seconds % 3600) / 60)分"
            } else if seconds >= 60 {
                timeLabel = "\(seconds / 60)分\(seconds % 60)秒"
            } else {
                timeLabel = "\(seconds)秒"
            }
            let hint = detail.contains("retry in")
                ? "（分間リクエスト上限: 15回/分）"
                : "（日次上限 1,500回/日 の可能性があります）"
            return "リクエスト上限に達しました \(hint)\n\(timeLabel)後に再試行できます\n詳細: \(detail.prefix(120))"
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

    private func extractRetryInfo(from text: String) -> (seconds: Int, raw: String) {
        // extract human-readable snippet from the error description
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
        // could not parse retry time → likely daily quota or unknown limit
        return (300, snippet.isEmpty ? text.prefix(200).description : snippet)
    }
}
