//
//  SettingsWindowView.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import SwiftUI

struct SettingsWindowView: View {
    @State private var appState = AppState.shared
    @State private var editingProviders: [ProviderConfig] = []
    @State private var tempApiKeys: [String] = []
    @State private var tempBaseUrls: [String] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Provider Settings")
                    .font(.headline)
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            Divider()

            // Provider 编辑列表
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(editingProviders.enumerated()), id: \.element.id) { index, provider in
                        ProviderEditCard(
                            provider: provider,
                            apiKey: tempApiKeys[index],
                            baseUrl: tempBaseUrls[index],
                            onApiKeyChange: { tempApiKeys[index] = $0 },
                            onBaseUrlChange: { tempBaseUrls[index] = $0 }
                        )
                    }
                }
                .padding(12)
            }

            Divider()

            // 保存按钮
            HStack(spacing: 12) {
                Button(action: {
                    saveSettings()
                    dismiss()
                }) {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
        }
        .frame(width: 400, height: 350)
        .onAppear {
            editingProviders = appState.configuration.providers
            tempApiKeys = editingProviders.map { $0.apiKey }
            tempBaseUrls = editingProviders.map { $0.baseUrl }
        }
    }

    private func saveSettings() {
        for index in 0..<editingProviders.count {
            editingProviders[index] = ProviderConfig(
                id: editingProviders[index].id,
                name: editingProviders[index].name,
                baseUrl: tempBaseUrls[index],
                apiKey: tempApiKeys[index]
            )
        }

        let newConfig = AppConfiguration(
            providers: editingProviders,
            selectedProviderId: appState.configuration.selectedProviderId
        )

        // 保存到文件
        try? ConfigService.saveConfiguration(newConfig)
        // 更新共享状态
        appState.configuration = newConfig
    }
}

struct ProviderEditCard: View {
    let provider: ProviderConfig
    var apiKey: String
    var baseUrl: String
    var onApiKeyChange: (String) -> Void
    var onBaseUrlChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(provider.name)
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack {
                Text("API Key:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                SecureField("Enter API key", text: Binding(
                    get: { apiKey },
                    set: onApiKeyChange
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
            }

            HStack {
                Text("Base URL:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                TextField("Enter base URL", text: Binding(
                    get: { baseUrl },
                    set: onBaseUrlChange
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
