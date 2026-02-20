//
//  MinimaxProvider.swift
//  ModelMana
//
//  Minimax AI provider implementation
//

import Foundation
import SwiftUI

/// Minimax provider - tracks API key quotas
@MainActor
@Observable
class MinimaxProvider: AIProvider {
    let id = "minimax"
    let name = "Minimax"
    let config: ProviderConfig

    /// Per-API-key quotas, keyed by apiKeyId
    private(set) var quotas: [String: QuotaState] = [:]

    init(config: ProviderConfig) {
        self.config = config

        // Initialize quota entries for all API keys
        for key in config.apiKeys {
            quotas[key.id] = .loading
        }
    }

    // MARK: - Provider Protocol

    func refreshUsage() async {
        // Minimax uses same quota pattern as Zhipu
        // TODO: Implement Minimax-specific quota API when available
        await withTaskGroup(of: Void.self) { group in
            for apiKey in config.apiKeys {
                group.addTask {
                    await self.refreshQuota(for: apiKey)
                }
            }
        }
    }

    var hasCustomDropdownPanel: Bool { false }

    func makeDropdownPanel() -> any View {
        EmptyView()
    }

    func makeSettingsView() -> (any View)? {
        nil  // Uses generic settings view
    }

    // MARK: - Quota Management

    /// Get quota for a specific API key
    func quota(for apiKeyId: String) -> QuotaState {
        quotas[apiKeyId] ?? .loaded([])
    }

    /// Refresh quota for a single API key
    private func refreshQuota(for apiKey: ApiKeyConfig) async {
        quotas[apiKey.id] = .loading

        // TODO: Implement Minimax quota API
        // For now, mark as error since API is not yet implemented
        quotas[apiKey.id] = .loaded([QuotaItem(title: "Session", status: .error("Not implemented"))])
    }

    /// Register a new API key (called when API key is added)
    func registerApiKey(_ apiKey: ApiKeyConfig) {
        if quotas[apiKey.id] == nil {
            quotas[apiKey.id] = .loading
        }
    }
}
