import Foundation

struct GroqService: AIService {
    static var effectiveAPIKey: String {
        (UserDefaults.standard.string(forKey: "groqAPIKey") ?? "").trimmingCharacters(in: .whitespaces)
    }

    static var isAPIKeyConfigured: Bool { !effectiveAPIKey.isEmpty }

    static var selectedModelName: String {
        UserDefaults.standard.string(forKey: "selectedGroqModel") ?? GroqModel.llama8b.rawValue
    }

    func send(prompt: String, maxOutputTokens: Int = 1024) async throws -> String {
        if GeminiService.isDebugMode {
            try? await Task.sleep(for: .milliseconds(400))
            return GeminiService.mockJSON(for: prompt)
        }

        let apiKey = Self.effectiveAPIKey
        guard !apiKey.isEmpty else { throw GeminiError.invalidAPIKey }

        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": Self.selectedModelName,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": maxOutputTokens,
            "temperature": 0.9
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode == 429 {
            let detail = String(data: data, encoding: .utf8) ?? ""
            let retryAfter = Int(http.value(forHTTPHeaderField: "retry-after") ?? "") ?? 60
            throw GeminiError.rateLimited(retryAfter: retryAfter + 2, detail: detail)
        }

        guard http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.apiError("Groq HTTP \(http.statusCode): \(detail.prefix(200))")
        }

        struct GroqResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(GroqResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw GeminiError.emptyResponse
        }
        return text
    }
}
