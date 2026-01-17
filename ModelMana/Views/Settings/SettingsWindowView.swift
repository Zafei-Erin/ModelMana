//
//  SettingsWindowView.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//  Refactored: 2025-01-17
//

import SwiftUI

struct SettingsWindowView: View {
    private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddProvider = false

    private let presetProviderIds = ["zhipu", "claude", "minimax"]

    private var presetProviders: [ProviderConfig] {
        presetProviderIds.compactMap { id in
            // If exists in config, use config (with API keys)
            if let existing = appState.configuration.providers.first(where: { $0.id == id }) {
                return existing
            }
            // Get default config from Provider enum
            if let provider = Provider.allCases.first(where: { $0.id == id }) {
                return ProviderConfig(
                    id: provider.id,
                    name: provider.rawValue,
                    baseUrl: provider.baseURL,
                    apiKeys: []
                )
            }
            return nil
        }
    }

    private var customProviders: [ProviderConfig] {
        appState.configuration.providers.filter { provider in
            !presetProviderIds.contains(provider.id)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Provider Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(nsColor: .controlTextColor))
            }
            .padding(.bottom, 12)

            Divider()

            // Provider list
            ScrollView {
                VStack(spacing: 12) {
                    // Built-in Providers section
                    Text("Preset Providers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(presetProviders) { provider in
                        ProviderSettingsCard(provider: provider)
                    }

                    // Custom Providers section
                    if !customProviders.isEmpty {
                        Text("Custom Providers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        ForEach(customProviders) { provider in
                            ProviderSettingsCard(provider: provider)
                        }
                    }

                    // Add new Provider button
                    addProviderButton
                }
                .padding(16)
            }
        }
        .frame(width: 500, height: 550)
        .sheet(isPresented: $showingAddProvider) {
            AddProviderSheet { newProvider in
                addProvider(newProvider)
            }
        }
    }

    // MARK: - Add Provider Button

    private var addProviderButton: some View {
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
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.blue.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func addProvider(_ provider: ProviderConfig) {
        var newConfig = appState.configuration
        newConfig.providers.append(provider)
        appState.configuration = newConfig
        try? ConfigService.saveConfiguration(appState.configuration)
    }
}

#Preview {
    SettingsWindowView()
}
