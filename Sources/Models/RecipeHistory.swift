import SwiftData
import Foundation

@Model
final class RecipeHistory {
    var name: String
    var ingredients: [String]
    var steps: [String]
    var rating: Int
    var createdAt: Date
    var photoData: Data?

    init(name: String, ingredients: [String], steps: [String], rating: Int, createdAt: Date = .now, photoData: Data? = nil) {
        self.name = name
        self.ingredients = ingredients
        self.steps = steps
        self.rating = max(1, min(5, rating))
        self.createdAt = createdAt
        self.photoData = photoData
    }
}
