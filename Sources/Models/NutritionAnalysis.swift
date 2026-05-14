import Foundation

struct NutritionAnalysis: Decodable {
    let summary: String
    let deficiencies: [Deficiency]

    struct Deficiency: Decodable, Identifiable {
        var id: UUID = UUID()
        let nutrient: String
        let reason: String
        let ingredients: [String]
        let recipeExamples: [RecipeExample]

        enum CodingKeys: String, CodingKey {
            case nutrient, reason, ingredients, recipeExamples
        }
    }

    struct RecipeExample: Decodable, Identifiable {
        var id: UUID = UUID()
        let name: String
        let description: String

        enum CodingKeys: String, CodingKey {
            case name, description
        }
    }
}
