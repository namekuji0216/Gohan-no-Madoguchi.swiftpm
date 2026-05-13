import SwiftUI
import SwiftData

struct InventoryView: View {
    @Query private var items: [PantryItem]

    var body: some View {
        NavigationStack {
            List(items) { item in
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.body)
                    Text(item.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("在庫管理")
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("食材がありません", systemImage: "cart")
                }
            }
        }
    }
}
