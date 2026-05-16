import Foundation

enum GeminiModel: String, CaseIterable, Identifiable {
    case flash20     = "gemini-2.0-flash"
    case flash20Lite = "gemini-2.0-flash-lite"
    case flash25     = "gemini-2.5-flash"
    case flash15     = "gemini-1.5-flash"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash20:     return "Gemini 2.0 Flash"
        case .flash20Lite: return "Gemini 2.0 Flash Lite"
        case .flash25:     return "Gemini 2.5 Flash"
        case .flash15:     return "Gemini 1.5 Flash"
        }
    }

    var note: String {
        switch self {
        case .flash20:     return "推奨・無料枠に最適"
        case .flash20Lite: return "軽量・低コスト"
        case .flash25:     return "高性能・思考トークンあり（消費大）"
        case .flash15:     return "旧モデル"
        }
    }
}
