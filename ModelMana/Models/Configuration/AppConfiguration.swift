//
//  AppConfiguration.swift
//  ModelMana
//
//  Created by refactoring from ProviderConfig.swift
//

import Foundation

/// Application configuration
struct AppConfiguration: Codable {
    var providers: [ProviderConfig]
    var selectedProviderId: String?
    var selectedApiKeyId: String?  // Globally selected API Key id

    /// Get currently selected Provider configuration
    var currentProvider: ProviderConfig? {
        guard let selectedId = selectedProviderId else { return nil }
        return providers.first { $0.id == selectedId }
    }

    /// Get currently selected API Key configuration (global)
    var currentApiKeyConfig: ApiKeyConfig? {
        guard let selectedId = selectedApiKeyId else { return nil }
        for provider in providers {
            if let keyConfig = provider.apiKeys.first(where: { $0.id == selectedId }) {
                return keyConfig
            }
        }
        return nil
    }

    /// Get currently selected API Key (global)
    var currentApiKey: String? {
        return currentApiKeyConfig?.key
    }

    init(providers: [ProviderConfig], selectedProviderId: String?, selectedApiKeyId: String? = nil) {
        self.providers = providers
        self.selectedProviderId = selectedProviderId
        self.selectedApiKeyId = selectedApiKeyId
    }
}
