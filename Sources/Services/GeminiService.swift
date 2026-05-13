import Foundation
import GoogleGenerativeAI

enum GeminiError: LocalizedError {
    case invalidAPIKey
    case emptyResponse
    case apiError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "APIキーが設定されていません。Sources/Secrets.swift を確認してください"
        case .emptyResponse:
            return "Gemini からの応答が空です"
        case .apiError(let message):
            return "Gemini APIエラー: \(message)"
        case .networkError(let e):
            return "通信エラー: \(e.localizedDescription)"
        }
    }
}

struct GeminiService {
    private let model: GenerativeModel

    // gemini-1.5-flash は無料枠で安定して使えるモデル
    init(apiKey: String = Secrets.geminiAPIKey, modelName: String = "gemini-1.5-flash") {
        // responseMIMEType はプロンプト側で指定するためここでは設定しない
        let config = GenerationConfig(
            temperature: 0.9,
            maxOutputTokens: 2048
        )
        model = GenerativeModel(
            name: modelName,
            apiKey: apiKey,
            generationConfig: config
        )
    }

    func send(prompt: String) async throws -> String {
        guard Secrets.geminiAPIKey != "YOUR_GEMINI_API_KEY_HERE",
              !Secrets.geminiAPIKey.isEmpty else {
            throw GeminiError.invalidAPIKey
        }

        do {
            let response = try await model.generateContent(prompt)
            guard let text = response.text, !text.isEmpty else {
                throw GeminiError.emptyResponse
            }
            return text
        } catch let error as GeminiError {
            throw error
        } catch let error as GenerateContentError {
            // SDK のエラーを詳細なメッセージに変換
            throw GeminiError.apiError(String(describing: error))
        } catch {
            throw GeminiError.networkError(error)
        }
    }
}
