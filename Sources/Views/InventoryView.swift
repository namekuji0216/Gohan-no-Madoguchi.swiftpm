import SwiftUI
import SwiftData

struct InventoryView: View {
    @Query(sort: \PantryItem.registeredAt) private var items: [PantryItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<PersistentIdentifier> = []

    private var allIDs: Set<PersistentIdentifier> { Set(items.map(\.persistentModelID)) }
    private var allSelected: Bool { !items.isEmpty && selectedIDs == allIDs }

    // セクションの順序を固定して Section 数の変化によるレイアウト崩れを防ぐ
    private func group(_ type: PantryItemType) -> [PantryItem] {
        items.filter { $0.type == type }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(PantryItemType.allCases, id: \.self) { type in
                    let g = group(type)
                    if !g.isEmpty {
                        Section {
                            ForEach(g) { item in
                                row(item)
                            }
                            .onDelete(perform: isSelecting ? nil : { offsets in
                                offsets.map { g[$0] }.forEach { modelContext.delete($0) }
                            })
                        } header: {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
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

    // MARK: - 行

    @ViewBuilder
    private func row(_ item: PantryItem) -> some View {
        let selected = selectedIDs.contains(item.persistentModelID)
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.blue : Color.secondary)
            }
            Text(item.name)
                .foregroundStyle(Color.primary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isSelecting else { return }
            if selected { selectedIDs.remove(item.persistentModelID) }
            else { selectedIDs.insert(item.persistentModelID) }
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
                if !items.isEmpty {
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
        items.filter { selectedIDs.contains($0.persistentModelID) }
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
                                    let item = PantryItem(name: preset, type: selectedType)
                                    modelContext.insert(item)
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
        let item = PantryItem(name: trimmed, type: selectedType)
        modelContext.insert(item)
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
