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
    var selectedClaudeCredential: ClaudeCredentialType?  // Claude credential type

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

    init(providers: [ProviderConfig], selectedProviderId: String?, selectedApiKeyId: String? = nil, selectedClaudeCredential: ClaudeCredentialType? = nil) {
        self.providers = providers
        self.selectedProviderId = selectedProviderId
        self.selectedApiKeyId = selectedApiKeyId
        self.selectedClaudeCredential = selectedClaudeCredential
    }

    /// Subscript for accessing provider by id
    subscript(id: String) -> ProviderConfig? {
        get { providers.first { $0.id == id } }
        set {
            if let index = providers.firstIndex(where: { $0.id == id }) {
                if let newValue = newValue {
                    providers[index] = newValue
                } else {
                    providers.remove(at: index)
                }
            } else if let newValue = newValue {
                providers.append(newValue)
            }
        }
    }
}
