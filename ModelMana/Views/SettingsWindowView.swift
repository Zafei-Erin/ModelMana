//
//  SettingsWindowView.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import SwiftUI

struct SettingsWindowView: View {
    private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddProvider = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Provider Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(nsColor: .controlTextColor))
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Provider 列表
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(appState.configuration.providers) { provider in
                        ProviderSettingsCard(provider: provider)
                    }

                    // 添加新 Provider 按钮
                    Button(action: {
                        showingAddProvider = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Add New Provider")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.blue.opacity(0.5), lineWidth: 1)
                            .background(Color(nsColor: .controlBackgroundColor))
                    )
                }
                .padding(16)
            }

            Divider()

            // 保存按钮
            HStack(spacing: 10) {
                Button(action: {
                    dismiss()
                }) {
                    Text("Done")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(16)
        }
        .frame(width: 500, height: 550)
        .sheet(isPresented: $showingAddProvider) {
            AddProviderSheet { newProvider in
                addProvider(newProvider)
            }
        }
    }

    private func addProvider(_ provider: ProviderConfig) {
        var newConfig = appState.configuration
        newConfig.providers.append(provider)
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)
    }
}

// Provider 设置卡片
struct ProviderSettingsCard: View {
    let provider: ProviderConfig
    @State private var apiKeys: [ApiKeyConfig]
    @State private var newKeyName: String = ""
    @State private var newKeyValue: String = ""
    @State private var showingAddKey = false
    @State private var showingEditProvider = false
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss
    private var appState = AppState.shared

    init(provider: ProviderConfig) {
        self.provider = provider
        self._apiKeys = State(initialValue: provider.apiKeys)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "server.rack")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                Text(provider.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(nsColor: .controlTextColor))
                Spacer()
                Text("\(apiKeys.count) key\(apiKeys.count != 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))

                // 编辑按钮
                Button(action: {
                    showingEditProvider = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                // 删除按钮（预置 provider 不可删除）
                if !isPresetProvider(provider.id) {
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Base URL (只读)
            VStack(alignment: .leading, spacing: 4) {
                Text("Base URL")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    .padding(.leading, 4)

                Text(provider.baseUrl)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
            }

            // API Keys 列表
            VStack(alignment: .leading, spacing: 6) {
                Text("API Keys")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    .padding(.leading, 4)

                ForEach(apiKeys) { keyConfig in
                    ApiKeyRow(
                        keyConfig: keyConfig,
                        isSelected: keyConfig.id == appState.configuration.selectedApiKeyId,
                        onSelect: {
                            selectKey(keyConfig.id)
                        },
                        onDelete: {
                            deleteKey(keyConfig.id)
                        }
                    )
                }

                // 添加新 Key 按钮
                Button(action: {
                    showingAddKey = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("Add API Key")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            if showingAddKey {
                AddApiKeyForm(
                    name: $newKeyName,
                    key: $newKeyValue,
                    onSave: {
                        addKey()
                        showingAddKey = false
                        newKeyName = ""
                        newKeyValue = ""
                    },
                    onCancel: {
                        showingAddKey = false
                        newKeyName = ""
                        newKeyValue = ""
                    }
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
        )
        .sheet(isPresented: $showingEditProvider) {
            EditProviderSheet(provider: provider) { updatedProvider in
                updateProvider(updatedProvider)
            }
        }
        .alert("Delete Provider", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteProvider()
            }
        } message: {
            Text("Are you sure you want to delete \"\(provider.name)\"? This action cannot be undone.")
        }
    }

    private var isPresetProvider: (String) -> Bool {
        { id in ["zhipu", "claude"].contains(id) }
    }

    private func selectKey(_ id: String) {
        guard let index = appState.configuration.providers.firstIndex(where: { $0.id == provider.id }) else { return }
        var newConfig = appState.configuration
        newConfig.providers[index].apiKeys = apiKeys
        newConfig.selectedProviderId = provider.id
        newConfig.selectedApiKeyId = id
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)
    }

    private func deleteKey(_ id: String) {
        apiKeys.removeAll { $0.id == id }
        var newConfig = appState.configuration
        guard let index = newConfig.providers.firstIndex(where: { $0.id == provider.id }) else { return }
        newConfig.providers[index].apiKeys = apiKeys
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)
    }

    private func addKey() {
        let newKey = ApiKeyConfig(name: newKeyName.isEmpty ? "Key \(apiKeys.count + 1)" : newKeyName, key: newKeyValue)
        apiKeys.append(newKey)
        var newConfig = appState.configuration
        guard let index = newConfig.providers.firstIndex(where: { $0.id == provider.id }) else { return }
        newConfig.providers[index].apiKeys = apiKeys
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)
    }

    private func updateProvider(_ updated: ProviderConfig) {
        var newConfig = appState.configuration
        guard let index = newConfig.providers.firstIndex(where: { $0.id == provider.id }) else { return }
        newConfig.providers[index] = updated
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)
    }

    private func deleteProvider() {
        var newConfig = appState.configuration
        newConfig.providers.removeAll { $0.id == provider.id }
        // 如果删除的是当前选中的，清空选中状态
        if newConfig.selectedProviderId == provider.id {
            newConfig.selectedProviderId = nil
            newConfig.selectedApiKeyId = nil
        }
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)
    }
}

// API Key 行
struct ApiKeyRow: View {
    let keyConfig: ApiKeyConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // 选中指示器
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .blue : .secondary)

            // Key 名称和遮罩
            VStack(alignment: .leading, spacing: 2) {
                Text(keyConfig.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(keyConfig.maskedKey)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 选择按钮
            if !isSelected {
                Button(action: onSelect) {
                    Text("Select")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            // 删除按钮
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
    }
}

// 添加 API Key 表单
struct AddApiKeyForm: View {
    @Binding var name: String
    @Binding var key: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 名称输入
            HStack {
                Text("Name:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                TextField("Key name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.caption)
            }

            // Key 输入
            HStack {
                Text("Key:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                SecureField("sk-...", text: $key)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
            }

            // 按钮
            HStack(spacing: 8) {
                Button(action: onSave) {
                    Text("Add")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(key.isEmpty)

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}

// 添加新 Provider 弹窗
struct AddProviderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var baseUrl: String = ""
    let onSave: (ProviderConfig) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add New Provider")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 表单
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Provider Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., OpenAI, Gemini", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Base URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., https://api.openai.com/v1", text: $baseUrl)
                        .textFieldStyle(.roundedBorder)
                }

                Spacer()

                // 按钮
                HStack(spacing: 10) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Add Provider") {
                        let newProvider = ProviderConfig(
                            id: UUID().uuidString,
                            name: name,
                            baseUrl: baseUrl,
                            apiKeys: []
                        )
                        onSave(newProvider)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || baseUrl.isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 350, height: 220)
    }
}

// 编辑 Provider 弹窗
struct EditProviderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let provider: ProviderConfig
    @State private var name: String
    @State private var baseUrl: String
    let onSave: (ProviderConfig) -> Void

    init(provider: ProviderConfig, onSave: @escaping (ProviderConfig) -> Void) {
        self.provider = provider
        self.onSave = onSave
        self._name = State(initialValue: provider.name)
        self._baseUrl = State(initialValue: provider.baseUrl)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Provider")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 表单
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Provider Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Provider name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Base URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Base URL", text: $baseUrl)
                        .textFieldStyle(.roundedBorder)
                }

                Spacer()

                // 按钮
                HStack(spacing: 10) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Save") {
                        let updated = ProviderConfig(
                            id: provider.id,
                            name: name,
                            baseUrl: baseUrl,
                            apiKeys: provider.apiKeys
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || baseUrl.isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 350, height: 220)
    }
}

#Preview {
    SettingsWindowView()
}
