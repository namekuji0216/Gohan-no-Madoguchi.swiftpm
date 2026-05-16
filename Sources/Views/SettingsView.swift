import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedAIProvider")  private var selectedProviderRaw = AIProvider.gemini.rawValue
    @AppStorage("geminiAPIKey")        private var geminiKey = ""
    @AppStorage("groqAPIKey")          private var groqKey = ""
    @AppStorage("selectedGeminiModel") private var selectedGeminiModelRaw = GeminiModel.flash25Lite.rawValue
    @AppStorage("selectedGroqModel")   private var selectedGroqModelRaw   = GroqModel.llama8b.rawValue

    @State private var inputKey = ""
    @State private var isKeyVisible = false
    @State private var showSavedBanner = false

    private var selectedProvider: AIProvider {
        AIProvider(rawValue: selectedProviderRaw) ?? .gemini
    }

    private var currentStoredKey: String {
        selectedProvider == .gemini ? geminiKey : groqKey
    }

    private var isConfigured: Bool {
        switch selectedProvider {
        case .gemini: return GeminiService.isAPIKeyConfigured
        case .groq:   return GroqService.isAPIKeyConfigured
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                providerSection
                apiKeySection
                modelSection
                debugSection
                infoSection
            }
            .navigationTitle("設定")
            .onChange(of: selectedProviderRaw) { _, _ in
                inputKey = currentStoredKey
            }
            .onAppear {
                inputKey = currentStoredKey
            }
            .overlay(alignment: .top) {
                if showSavedBanner {
                    savedBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - プロバイダー選択

    private var providerSection: some View {
        Section {
            Picker("AIプロバイダー", selection: $selectedProviderRaw) {
                ForEach(AIProvider.allCases) { provider in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.displayName)
                        Text(provider.freeNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(provider.rawValue)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Label("AIプロバイダー", systemImage: "cpu")
        }
    }

    // MARK: - API キー

    private var apiKeySection: some View {
        Section {
            HStack {
                Group {
                    if isKeyVisible {
                        TextField("APIキーを入力", text: $inputKey)
                    } else {
                        SecureField("APIキーを入力", text: $inputKey)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)

                Button {
                    isKeyVisible.toggle()
                } label: {
                    Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button("保存") { saveKey() }
                    .disabled(inputKey.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
                if !currentStoredKey.isEmpty {
                    Button("削除", role: .destructive) {
                        if selectedProvider == .gemini { geminiKey = "" } else { groqKey = "" }
                        inputKey = ""
                    }
                }
            }
        } header: {
            Label("\(selectedProvider.displayName) API キー", systemImage: "key")
        } footer: {
            HStack(spacing: 6) {
                Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(isConfigured ? .green : .orange)
                Text(isConfigured
                    ? "APIキーが設定されています"
                    : "APIキーが未設定です。献立提案・栄養分析を使用するには登録してください。")
                    .foregroundStyle(isConfigured ? .green : .orange)
            }
            .font(.caption)
            .padding(.top, 4)
        }
    }

    // MARK: - モデル選択

    @ViewBuilder
    private var modelSection: some View {
        Section {
            if selectedProvider == .gemini {
                Picker("モデル", selection: $selectedGeminiModelRaw) {
                    ForEach(GeminiModel.allCases) { model in
                        modelRow(name: model.displayName, note: model.note)
                            .tag(model.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } else {
                Picker("モデル", selection: $selectedGroqModelRaw) {
                    ForEach(GroqModel.allCases) { model in
                        modelRow(name: model.displayName, note: model.note)
                            .tag(model.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        } header: {
            Label("使用モデル", systemImage: "sparkles")
        }
    }

    private func modelRow(name: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
            Text(note).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - デバッグ

    private var debugSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { GeminiService.isDebugMode },
                set: { GeminiService.isDebugMode = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("デバッグモード")
                    Text("APIを使わずモックデータで動作確認")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("開発者向け", systemImage: "hammer")
        }
    }

    // MARK: - 取得方法

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("APIキーの取得先")
                    .font(.caption.bold())
                Text("・Google Gemini: aistudio.google.com/app/apikey")
                    .font(.caption).foregroundStyle(.secondary)
                Text("・Groq: console.groq.com/keys")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("無料枠の比較")
                    .font(.caption.bold())
                Text("Gemini: 15回/分・1,500回/日")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Groq: 最大20,000TPM・14,400回/日")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        } header: {
            Label("情報", systemImage: "info.circle")
        }
    }

    // MARK: - 保存済みバナー

    private var savedBanner: some View {
        Label("APIキーを保存しました", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.green.gradient, in: Capsule())
            .shadow(radius: 4)
    }

    private func saveKey() {
        let trimmed = inputKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if selectedProvider == .gemini { geminiKey = trimmed } else { groqKey = trimmed }
        withAnimation(.spring(duration: 0.3)) { showSavedBanner = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showSavedBanner = false }
        }
    }
}
