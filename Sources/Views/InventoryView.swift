import SwiftUI
import SwiftData

struct InventoryView: View {
    @Query(sort: \PantryItem.registeredAt) private var items: [PantryItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false

    private var seasonings: [PantryItem] { items.filter { $0.type == .seasoning } }
    private var ingredients: [PantryItem] { items.filter { $0.type == .ingredient } }

    var body: some View {
        NavigationStack {
            List {
                if !seasonings.isEmpty {
                    Section("調味料") {
                        ForEach(seasonings) { item in
                            Text(item.name)
                        }
                        .onDelete { offsets in
                            delete(from: seasonings, at: offsets)
                        }
                    }
                }
                if !ingredients.isEmpty {
                    Section("食材") {
                        ForEach(ingredients) { item in
                            Text(item.name)
                        }
                        .onDelete { offsets in
                            delete(from: ingredients, at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("在庫管理")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("追加", systemImage: "plus") {
                        showingAddSheet = true
                    }
                }
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("食材・調味料がありません", systemImage: "cart")
                    } description: {
                        Text("右上の＋ボタンから登録してください")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddPantryItemView()
            }
        }
    }

    private func delete(from list: [PantryItem], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(list[index])
        }
    }
}

// MARK: - 追加シート

private struct AddPantryItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: PantryItemType = .ingredient
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("例：玉ねぎ、醤油…", text: $name)
                        .focused($nameFocused)
                }
                Section("種類") {
                    Picker("種類", selection: $type) {
                        ForEach(PantryItemType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("食材を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { nameFocused = true }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(PantryItem(name: trimmed, type: type))
        dismiss()
    }
}
