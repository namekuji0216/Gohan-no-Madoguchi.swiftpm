import Foundation

struct MenuSuggestion: Identifiable, Decodable {
    var id = UUID()
    let name: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case name, description
    }
}

struct DetailedRecipe: Decodable {
    let name: String
    let ingredients: [String]
    let steps: [String]
}

enum MoodTag: String, CaseIterable, Identifiable {
    case easy    = "お手軽"
    case light   = "あっさり"
    case hearty  = "がっつり"
    case healthy = "ヘルシー"
    case japanese = "和食"
    case western  = "洋食"
    case chinese  = "中華"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .easy:     "bolt"
        case .light:    "leaf"
        case .hearty:   "flame"
        case .healthy:  "heart"
        case .japanese: "wave.3.right"
        case .western:  "fork.knife"
        case .chinese:  "takeoutbag.and.cup.and.straw"
        }
    }
}
