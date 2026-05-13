import SwiftData
import Foundation

enum PantryItemType: String, Codable, CaseIterable {
    case seasoning = "調味料"
    case ingredient = "食材"
}

@Model
final class PantryItem {
    var name: String
    var type: PantryItemType
    var registeredAt: Date

    init(name: String, type: PantryItemType, registeredAt: Date = .now) {
        self.name = name
        self.type = type
        self.registeredAt = registeredAt
    }
}
