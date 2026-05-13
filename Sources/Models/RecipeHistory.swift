import SwiftData
import Foundation

@Model
final class RecipeHistory {
    var name: String
    var ingredients: [String]
    var steps: [String]
    var rating: Int
    var createdAt: Date

    init(name: String, ingredients: [String], steps: [String], rating: Int, createdAt: Date = .now) {
        self.name = name
        self.ingredients = ingredients
        self.steps = steps
        self.rating = max(1, min(5, rating))
        self.createdAt = createdAt
    }
}
