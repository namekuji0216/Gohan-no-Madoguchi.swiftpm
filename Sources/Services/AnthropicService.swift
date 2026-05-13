import Foundation

enum AnthropicError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:        return "APIキーが設定されていません"
        case .networkError(let e): return "通信エラー: \(e.localizedDescription)"
        case .invalidResponse:     return "サーバーからの応答が不正です"
        case .decodingError(let s): return "データ解析エラー: \(s)"
        }
    }
}

struct AnthropicService {
    private let apiKey: String
    private let model: String
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    init(apiKey: String = Config.anthropicAPIKey, model: String = Config.claudeModel) {
        self.apiKey = apiKey
        self.model = model
    }

    func send(prompt: String, maxTokens: Int = 1024) async throws -> String {
        guard apiKey != "YOUR_API_KEY_HERE", !apiKey.isEmpty else {
            throw AnthropicError.invalidAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            throw AnthropicError.networkError(error)
        }

        struct APIResponse: Decodable {
            struct Content: Decodable { let text: String }
            let content: [Content]
        }

        guard let response = try? JSONDecoder().decode(APIResponse.self, from: data),
              let text = response.content.first?.text else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw AnthropicError.decodingError(raw)
        }
        return text
    }
}
