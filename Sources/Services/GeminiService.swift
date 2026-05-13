import Foundation
import GoogleGenerativeAI

enum GeminiError: LocalizedError {
    case invalidAPIKey
    case emptyResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:        return "APIキーが設定されていません。Sources/Secrets.swift を確認してください"
        case .emptyResponse:        return "Gemini からの応答が空です"
        case .networkError(let e): return "通信エラー: \(e.localizedDescription)"
        }
    }
}

struct GeminiService {
    private let model: GenerativeModel

    // モデル名は Config で一元管理
    init(apiKey: String = Secrets.geminiAPIKey, modelName: String = "gemini-2.0-flash") {
        let config = GenerationConfig(
            temperature: 0.9,
            maxOutputTokens: 2048,
            responseMIMEType: "application/json"  // JSON を直接返させる
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
        } catch {
            throw GeminiError.networkError(error)
        }
    }
}
