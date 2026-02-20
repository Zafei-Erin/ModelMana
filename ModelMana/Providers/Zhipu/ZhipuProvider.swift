//
//  ZhipuProvider.swift
//  ModelMana
//
//  Zhipu AI provider implementation
//

import Foundation
import SwiftUI

/// Zhipu provider - tracks API key quotas
@MainActor
@Observable
class ZhipuProvider: AIProvider {
    let id = "zhipu"
    let name = "Zhipu"
    let config: ProviderConfig

    /// Per-API-key quotas, keyed by apiKeyId
    private(set) var quotas: [String: ApiKeyQuota] = [:]

    init(config: ProviderConfig) {
        self.config = config

        // Initialize quota entries for all API keys
        for key in config.apiKeys {
            quotas[key.id] = ApiKeyQuota(status: .loading)
        }
    }

    // MARK: - Provider Protocol

    func refreshUsage() async {
        if !config.apiKeys.isEmpty {
            Logger.log("Zhipu", "Refreshing...")
        }
        // Refresh quota for each API key in parallel
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
    func quota(for apiKeyId: String) -> ApiKeyQuota {
        quotas[apiKeyId] ?? ApiKeyQuota(status: .error("API key not found"))
    }

    /// Refresh quota for a single API key
    private func refreshQuota(for apiKey: ApiKeyConfig) async {
        // Set to loading state first
        quotas[apiKey.id] = ApiKeyQuota(status: .loading)

        let result = await ZhipuQuotaService.fetchQuota(apiKey: apiKey.key)

        switch result {
        case .success(let data):
            Logger.log("Zhipu", "Quota: \(data.percentage)%")
            quotas[apiKey.id] = ApiKeyQuota(
                status: .success(percentage: data.percentage, nextResetTime: data.nextResetTime),
                title: "Session (5h)"
            )
        case .failure(let error):
            Logger.error("Zhipu", error.localizedDescription)
            quotas[apiKey.id] = ApiKeyQuota(status: .error(error.localizedDescription))
        }
    }

    /// Register a new API key (called when API key is added)
    func registerApiKey(_ apiKey: ApiKeyConfig) {
        if quotas[apiKey.id] == nil {
            quotas[apiKey.id] = ApiKeyQuota(status: .loading)
        }
    }
}
