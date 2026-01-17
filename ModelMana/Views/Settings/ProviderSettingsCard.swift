//
//  ProviderSettingsCard.swift
//  ModelMana
//
//  Created by refactoring from SettingsWindowView
//

import SwiftUI

struct ProviderSettingsCard: View {
    let provider: ProviderConfig
    @State private var apiKeys: [ApiKeyConfig]
    @State private var newKeyName: String = ""
    @State private var newKeyValue: String = ""
    @State private var showingAddKey = false
    @State private var showingEditProvider = false
    @State private var showingDeleteAlert = false
    @State private var showingEditKey = false
    @State private var editingKey: ApiKeyConfig?
    @Environment(\.dismiss) private var dismiss
    private var appState = AppState.shared

    init(provider: ProviderConfig) {
        self.provider = provider
        self._apiKeys = State(initialValue: provider.apiKeys)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            baseUrlSection
            apiKeysSection
            addKeyForm
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
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteProvider()
            }
        } message: {
            Text(
                "Are you sure you want to delete \"\(provider.name)\"? This action cannot be undone."
            )
        }
        .sheet(isPresented: $showingEditKey) {
            if let key = editingKey {
                EditKeySheet(keyConfig: key) { updatedName, updatedKey in
                    updateKey(keyId: key.id, name: updatedName, keyValue: updatedKey)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
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

            // Edit button
            Button(action: {
                showingEditProvider = true
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            // Delete button (preset providers cannot be deleted)
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
    }

    // MARK: - Base URL Section

    private var baseUrlSection: some View {
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
    }

    // MARK: - API Keys Section

    private var apiKeysSection: some View {
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
                    },
                    onEdit: {
                        editKey(keyConfig)
                    }
                )
            }

            // Add new key button
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
    }

    // MARK: - Add Key Form

    @ViewBuilder
    private var addKeyForm: some View {
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

    // MARK: - Helper Properties

    private var isPresetProvider: (String) -> Bool {
        { id in ["zhipu", "claude", "minimax"].contains(id) }
    }

    // MARK: - Actions

    private func editKey(_ keyConfig: ApiKeyConfig) {
        editingKey = keyConfig
        showingEditKey = true
    }

    private func updateKey(keyId: String, name: String, keyValue: String) {
        guard let index = apiKeys.firstIndex(where: { $0.id == keyId }) else { return }
        apiKeys[index] = ApiKeyConfig(id: keyId, name: name, key: keyValue)
        var newConfig = appState.configuration
        if let providerIndex = newConfig.providers.firstIndex(where: { $0.id == provider.id }) {
            newConfig.providers[providerIndex].apiKeys = apiKeys
        } else {
            // Provider not in config (preset provider first time adding key), add to config
            newConfig.providers.append(
                ProviderConfig(
                    id: provider.id,
                    name: provider.name,
                    baseUrl: provider.baseUrl,
                    apiKeys: apiKeys
                ))
        }
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)

        // If updating the currently selected key, sync to Claude settings
        if keyId == appState.configuration.selectedApiKeyId {
            updateClaudeSettingsIfNeeded()
        }
    }

    private func updateClaudeSettingsIfNeeded() {
        // Get currently selected provider and API key
        guard let selectedApiKeyId = appState.configuration.selectedApiKeyId,
            let selectedProviderId = appState.configuration.selectedProviderId,
            let providerConfig = appState.configuration.providers.first(where: {
                $0.id == selectedProviderId
            }),
            let apiKeyConfig = providerConfig.apiKeys.first(where: { $0.id == selectedApiKeyId })
        else { return }

        // Sync update to Claude settings
        do {
            try SettingsFileService.writeSettings(
                baseUrl: providerConfig.baseUrl,
                apiKey: apiKeyConfig.key
            )
            print("[ModelMana] ✅ Synced updated API key to Claude settings")
        } catch {
            print(
                "[ModelMana] ❌ WARNING: Failed to sync Claude settings: \(error.localizedDescription)"
            )
        }
    }

    private func selectKey(_ id: String) {
        var newConfig = appState.configuration
        if let providerIndex = newConfig.providers.firstIndex(where: { $0.id == provider.id }) {
            newConfig.providers[providerIndex].apiKeys = apiKeys
        } else {
            // Provider not in config (preset provider first time selecting), add to config
            newConfig.providers.append(
                ProviderConfig(
                    id: provider.id,
                    name: provider.name,
                    baseUrl: provider.baseUrl,
                    apiKeys: apiKeys
                ))
        }
        newConfig.selectedProviderId = provider.id
        newConfig.selectedApiKeyId = id
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)

        // Track credential type if this is Claude
        if provider.id == "claude" {
            AppState.shared.selectedClaudeCredential = .manualKey(id)
        }
    }

    private func deleteKey(_ id: String) {
        apiKeys.removeAll { $0.id == id }
        var newConfig = appState.configuration
        if let providerIndex = newConfig.providers.firstIndex(where: { $0.id == provider.id }) {
            newConfig.providers[providerIndex].apiKeys = apiKeys
        } else {
            // Provider not in config (preset provider first time deleting key), add to config
            newConfig.providers.append(
                ProviderConfig(
                    id: provider.id,
                    name: provider.name,
                    baseUrl: provider.baseUrl,
                    apiKeys: apiKeys
                ))
        }
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)
    }

    private func addKey() {
        let newKey = ApiKeyConfig(
            name: newKeyName.isEmpty ? "Key \(apiKeys.count + 1)" : newKeyName, key: newKeyValue)
        apiKeys.append(newKey)
        var newConfig = appState.configuration
        if let providerIndex = newConfig.providers.firstIndex(where: { $0.id == provider.id }) {
            newConfig.providers[providerIndex].apiKeys = apiKeys
        } else {
            // Provider not in config (preset provider first time adding key), add to config
            newConfig.providers.append(
                ProviderConfig(
                    id: provider.id,
                    name: provider.name,
                    baseUrl: provider.baseUrl,
                    apiKeys: apiKeys
                ))
        }
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)
        appState.registerApiKey(newKey.id)
    }

    private func updateProvider(_ updated: ProviderConfig) {
        var newConfig = appState.configuration
        guard let index = newConfig.providers.firstIndex(where: { $0.id == provider.id }) else {
            return
        }
        newConfig.providers[index] = updated
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)
    }

    private func deleteProvider() {
        var newConfig = appState.configuration
        newConfig.providers.removeAll { $0.id == provider.id }
        // If deleting the currently selected, clear selection
        if newConfig.selectedProviderId == provider.id {
            newConfig.selectedProviderId = nil
            newConfig.selectedApiKeyId = nil
        }
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)
    }
}
