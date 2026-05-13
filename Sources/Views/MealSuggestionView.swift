import SwiftUI
import SwiftData

struct MealSuggestionView: View {
    @Query private var items: [PantryItem]

    var body: some View {
        NavigationStack {
            ContentUnavailableView("献立を提案します", systemImage: "fork.knife")
                .navigationTitle("献立提案")
        }
    }
}
