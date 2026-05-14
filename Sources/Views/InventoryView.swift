import SwiftUI
import SwiftData

struct InventoryView: View {
    @Query(sort: \PantryItem.registeredAt) private var items: [PantryItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<PersistentIdentifier> = []

    private var allIDs: Set<PersistentIdentifier> {
        Set(items.map(\.persistentModelID))
    }
    private var allSelected: Bool { selectedIDs == allIDs && !items.isEmpty }

    var body: some View {
        NavigationStack {
            List {
                ForEach(PantryItemType.allCases, id: \.self) { type in
                    let group = items.filter { $0.type == type }
                    if !group.isEmpty {
                        Section(header: Label(type.rawValue, systemImage: type.icon)) {
                            ForEach(group) { item in
                                ItemRow(
                                    item: item,
                                    isSelecting: isSelecting,
                                    isSelected: selectedIDs.contains(item.persistentModelID)
                                ) {
                                    toggleSelection(item)
                                }
                            }
                            .onDelete(perform: isSelecting ? nil : { offsets in
                                for i in offsets { modelContext.delete(group[i]) }
                            })
                        }
                    }
                }
            }
            .navigationTitle("在庫管理")
            .toolbar { toolbarContent }
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
            .animation(.default, value: isSelecting)
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
                    selectedIDs = allSelected ? [] : allIDs
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    deleteSelected()
                } label: {
                    Label("削除（\(selectedIDs.count)件）", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selectedIDs.isEmpty)
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                if !items.isEmpty {
                    Button("選択", systemImage: "checkmark.circle") {
                        isSelecting = true
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("追加", systemImage: "plus") { showingAddSheet = true }
            }
        }
    }

    // MARK: - Actions

    private func toggleSelection(_ item: PantryItem) {
        let id = item.persistentModelID
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func deleteSelected() {
        let toDelete = items.filter { selectedIDs.contains($0.persistentModelID) }
        toDelete.forEach { modelContext.delete($0) }
        exitSelection()
    }

    private func exitSelection() {
        isSelecting = false
        selectedIDs.removeAll()
    }
}

// MARK: - 行

private struct ItemRow: View {
    let item: PantryItem
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
                Text(item.name)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isSelecting)
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
                                    if !added {
                                        modelContext.insert(PantryItem(name: preset, type: selectedType))
                                    }
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
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
    }
}
