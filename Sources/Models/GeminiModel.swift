import Foundation

enum GeminiModel: String, CaseIterable, Identifiable {
    case flash25Lite = "gemini-2.5-flash-lite"
    case flash25     = "gemini-2.5-flash"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash25Lite: return "Gemini 2.5 Flash Lite"
        case .flash25:     return "Gemini 2.5 Flash"
        }
    }

    var note: String {
        switch self {
        case .flash25Lite: return "軽量・低コスト・推奨"
        case .flash25:     return "高性能・思考トークンあり（消費大）"
        }
    }
}
