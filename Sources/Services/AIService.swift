import Foundation

// MARK: - プロトコル

protocol AIService {
    func send(prompt: String, maxOutputTokens: Int) async throws -> String
}

// MARK: - プロバイダー

enum AIProvider: String, CaseIterable, Identifiable {
    case gemini = "gemini"
    case groq   = "groq"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .groq:   return "Groq"
        }
    }

    var freeNote: String {
        switch self {
        case .gemini: return "15回/分・1,500回/日"
        case .groq:   return "最大20,000TPM・14,400回/日"
        }
    }

    var apiKeyStorageKey: String {
        switch self {
        case .gemini: return "geminiAPIKey"
        case .groq:   return "groqAPIKey"
        }
    }

    var getKeyURL: String {
        switch self {
        case .gemini: return "https://aistudio.google.com/app/apikey"
        case .groq:   return "https://console.groq.com/keys"
        }
    }
}

// MARK: - ファクトリー

struct AIServiceFactory {
    static var selectedProvider: AIProvider {
        AIProvider(rawValue: UserDefaults.standard.string(forKey: "selectedAIProvider") ?? "") ?? .gemini
    }

    static var isAPIKeyConfigured: Bool {
        switch selectedProvider {
        case .gemini: return GeminiService.isAPIKeyConfigured
        case .groq:   return GroqService.isAPIKeyConfigured
        }
    }

    static func make() -> any AIService {
        switch selectedProvider {
        case .gemini: return GeminiService()
        case .groq:   return GroqService()
        }
    }
}
