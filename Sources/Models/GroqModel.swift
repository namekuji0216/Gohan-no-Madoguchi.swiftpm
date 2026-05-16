import Foundation

enum GroqModel: String, CaseIterable, Identifiable {
    case llama70b = "llama-3.3-70b-versatile"
    case llama8b  = "llama-3.1-8b-instant"
    case gemma9b  = "gemma2-9b-it"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .llama70b: return "Llama 3.3 70B"
        case .llama8b:  return "Llama 3.1 8B"
        case .gemma9b:  return "Gemma 2 9B"
        }
    }

    var note: String {
        switch self {
        case .llama70b: return "高性能・6,000TPM/分"
        case .llama8b:  return "高速・低コスト・20,000TPM/分"
        case .gemma9b:  return "Google製・15,000TPM/分"
        }
    }
}
