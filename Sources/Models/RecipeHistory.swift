import SwiftData
import Foundation

@Model
final class RecipeHistory {
    var name: String
    var ingredients: [String]   // 保存時の人数（servings）での分量
    var steps: [String]
    var rating: Int
    var servings: Int           // 保存時の人数
    var createdAt: Date
    var photoData: Data?

    init(name: String, ingredients: [String], steps: [String],
         rating: Int, servings: Int = 2, createdAt: Date = .now, photoData: Data? = nil) {
        self.name = name
        self.ingredients = ingredients
        self.steps = steps
        self.rating = max(1, min(5, rating))
        self.servings = servings
        self.createdAt = createdAt
        self.photoData = photoData
    }
}
