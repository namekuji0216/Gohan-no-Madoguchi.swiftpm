import SwiftUI

struct SettingsView: View {
    @AppStorage("geminiAPIKey") private var savedKey = ""
    @AppStorage("selectedGeminiModel") private var selectedModelRaw = GeminiModel.flash25Lite.rawValue
    @State private var inputKey = ""
    @State private var isKeyVisible = false
    @State private var showSavedBanner = false

    private var selectedModel: GeminiModel {
        GeminiModel(rawValue: selectedModelRaw) ?? .flash25Lite
    }

    private var isConfigured: Bool {
        !effectiveKey.isEmpty && effectiveKey != "YOUR_GEMINI_API_KEY_HERE"
    }

    private var effectiveKey: String {
        savedKey.trimmingCharacters(in: .whitespaces).isEmpty
            ? Secrets.geminiAPIKey
            : savedKey.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                apiKeySection
                modelSection
                debugSection
                infoSection
            }
            .navigationTitle("設定")
            .onAppear {
                // AppStorage の値で入力欄を初期化（Secrets.swift の値は表示しない）
                inputKey = savedKey
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

    // MARK: - API キーセクション

    private var apiKeySection: some View {
        Section {
            HStack {
                Group {
                    if isKeyVisible {
                        TextField("AIzaSy...", text: $inputKey)
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
                Button("保存") {
                    saveKey()
                }
                .disabled(inputKey.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()

                if !savedKey.isEmpty {
                    Button("削除", role: .destructive) {
                        savedKey = ""
                        inputKey = ""
                    }
                }
            }
        } header: {
            Label("Gemini API キー", systemImage: "key")
        } footer: {
            HStack(spacing: 6) {
                Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(isConfigured ? .green : .orange)
                Text(isConfigured ? "APIキーが設定されています" : "APIキーが未設定です。献立提案・栄養分析を使用するにはキーを登録してください。")
                    .foregroundStyle(isConfigured ? .green : .orange)
            }
            .font(.caption)
            .padding(.top, 4)
        }
    }

    // MARK: - モデル選択セクション

    private var modelSection: some View {
        Section {
            Picker("モデル", selection: $selectedModelRaw) {
                ForEach(GeminiModel.allCases) { model in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.displayName)
                        Text(model.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(model.rawValue)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Label("使用モデル", systemImage: "cpu")
        } footer: {
            Text("現在: \(selectedModel.displayName)（\(selectedModel.note)）")
                .font(.caption)
        }
    }

    // MARK: - デバッグセクション

    private var debugSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { GeminiService.isDebugMode },
                set: { GeminiService.isDebugMode = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("デバッグモード")
                    Text("APIを使わずモックデータで動作確認")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("開発者向け", systemImage: "hammer")
        }
    }

    // MARK: - 取得方法セクション

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Google AI Studio（aistudio.google.com）にアクセス")
                Text("2. 「Get API key」→「Create API key」を選択")
                Text("3. 生成されたキーをコピーして上の欄に貼り付け")
                Text("4. 「保存」をタップ")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("無料枠の制限")
                    .font(.caption.bold())
                Group {
                    Text("・分間リクエスト: 15回/分")
                    Text("・日次リクエスト: 1,500回/日（UTC 0:00 リセット）")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Label("APIキーの取得方法", systemImage: "info.circle")
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

    // MARK: - 保存処理

    private func saveKey() {
        let trimmed = inputKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        savedKey = trimmed
        withAnimation(.spring(duration: 0.3)) { showSavedBanner = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showSavedBanner = false }
        }
    }
}
