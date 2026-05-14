import SwiftUI
import SwiftData

struct InventoryView: View {
    // カテゴリごとに独立したクエリ — Swift の filter に頼らない
    @Query(filter: #Predicate<PantryItem> { $0.typeRawValue == "調味料" },
           sort: \PantryItem.registeredAt) private var seasonings: [PantryItem]
    @Query(filter: #Predicate<PantryItem> { $0.typeRawValue == "肉" },
           sort: \PantryItem.registeredAt) private var meats: [PantryItem]
    @Query(filter: #Predicate<PantryItem> { $0.typeRawValue == "魚" },
           sort: \PantryItem.registeredAt) private var fishes: [PantryItem]
    @Query(filter: #Predicate<PantryItem> { $0.typeRawValue == "野菜" },
           sort: \PantryItem.registeredAt) private var vegetables: [PantryItem]
    @Query(filter: #Predicate<PantryItem> { $0.typeRawValue == "その他" },
           sort: \PantryItem.registeredAt) private var others: [PantryItem]

    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<PersistentIdentifier> = []

    private var allItems: [PantryItem] {
        seasonings + meats + fishes + vegetables + others
    }
    private var isEmpty: Bool { allItems.isEmpty }
    private var allSelected: Bool {
        !isEmpty && selectedIDs.count == allItems.count
    }

    var body: some View {
        NavigationStack {
            List {
                itemSection(type: .seasoning, items: seasonings)
                itemSection(type: .meat,      items: meats)
                itemSection(type: .fish,      items: fishes)
                itemSection(type: .vegetable, items: vegetables)
                itemSection(type: .other,     items: others)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("在庫管理")
            .toolbar { toolbarContent }
            .overlay {
                if isEmpty {
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
            .animation(.default, value: isSelecting)
        }
    }

    // MARK: - Section

    @ViewBuilder
    private func itemSection(type: PantryItemType, items: [PantryItem]) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        if isSelecting {
                            let sel = selectedIDs.contains(item.persistentModelID)
                            Image(systemName: sel ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(sel ? Color.blue : Color.secondary)
                        }
                        Text(item.name)
                            .foregroundStyle(Color.primary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard isSelecting else { return }
                        let id = item.persistentModelID
                        if selectedIDs.contains(id) { selectedIDs.remove(id) }
                        else { selectedIDs.insert(id) }
                    }
                }
                .onDelete(perform: isSelecting ? nil : { offsets in
                    offsets.map { items[$0] }.forEach { modelContext.delete($0) }
                })
            } header: {
                Label(type.rawValue, systemImage: type.icon)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { exitSelection() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(allSelected ? "全解除" : "全選択") {
                    if allSelected { selectedIDs.removeAll() }
                    else { selectedIDs = Set(allItems.map(\.persistentModelID)) }
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) { deleteSelected() } label: {
                    Label("削除（\(selectedIDs.count)件）", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selectedIDs.isEmpty)
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                if !isEmpty {
                    Button("選択", systemImage: "checkmark.circle") { isSelecting = true }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("追加", systemImage: "plus") { showingAddSheet = true }
            }
        }
    }

    // MARK: - Actions

    private func deleteSelected() {
        allItems.filter { selectedIDs.contains($0.persistentModelID) }
                .forEach { modelContext.delete($0) }
        exitSelection()
    }

    private func exitSelection() {
        isSelecting = false
        selectedIDs.removeAll()
    }
}

// MARK: - 追加シート

private struct AddPantryItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingItems: [PantryItem]

    @State private var selectedType: PantryItemType = .vegetable
    @State private var customName = ""
    @FocusState private var customFocused: Bool

    private var registeredNames: Set<String> { Set(existingItems.map(\.name)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("種類", selection: $selectedType) {
                    ForEach(PantryItemType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    Section("よく使う食材をタップで追加") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                            ForEach(selectedType.presets, id: \.self) { preset in
                                let added = registeredNames.contains(preset)
                                PresetChip(name: preset, isAdded: added) {
                                    guard !added else { return }
                                    modelContext.insert(PantryItem(name: preset, type: selectedType))
                                    try? modelContext.save()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Section("手動で追加") {
                        HStack {
                            TextField("名前を入力…", text: $customName)
                                .focused($customFocused)
                                .submitLabel(.done)
                                .onSubmit(saveCustom)
                            Button("追加", action: saveCustom)
                                .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("食材を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func saveCustom() {
        let trimmed = customName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(PantryItem(name: trimmed, type: selectedType))
        try? modelContext.save()
        customName = ""
    }
}

// MARK: - プリセットチップ

private struct PresetChip: View {
    let name: String
    let isAdded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isAdded ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(Color(.systemGray6)),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .foregroundStyle(isAdded ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .overlay(alignment: .topTrailing) {
                    if isAdded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.tint)
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
    }
}
