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
        if !config.apiKeys.isEmpty {
            Logger.log("Minimax", "Refreshing...")
        }
        await withTaskGroup(of: Void.self) { group in
            for apiKey in config.apiKeys {
                group.addTask {
                    await self.refreshQuota(for: apiKey)
                }
            }
        }
    }

    var hasCustomDropdownPanel: Bool { false }

    /// Get current usage percentage from selected API key's quota (session)
    var usagePercentage: Double? {
        let selectedKeyId = ProviderRegistry.shared.configuration.selectedApiKeyId
        guard let selectedKeyId = selectedKeyId,
              !selectedKeyId.isEmpty,
              case .loaded(let items) = quota(for: selectedKeyId) else {
            // Fallback: get first available quota
            return firstAvailableQuotaPercentage
        }
        // Get first available quota (Minimax has single session quota)
        return items.first?.percentage
    }

    /// Get first available quota percentage as fallback
    private var firstAvailableQuotaPercentage: Double? {
        for key in config.apiKeys {
            if case .loaded(let items) = quota(for: key.id) {
                if let percentage = items.first?.percentage {
                    return percentage
                }
            }
        }
        return nil
    }

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

        let result = await MiniMaxQuotaService.fetchQuota(apiKey: apiKey.key)

        switch result {
        case .success(let items):
            if let percentage = items.first?.percentage {
                Logger.log("Minimax", "Quota: \(Int(percentage ?? 0))%")
            }
            quotas[apiKey.id] = .loaded(items)
        case .failure(let error):
            Logger.error("Minimax", error.localizedDescription)
            quotas[apiKey.id] = .loaded([
                QuotaItem(title: "Session", status: .error(error.localizedDescription))
            ])
        }
    }

    /// Register a new API key (called when API key is added)
    func registerApiKey(_ apiKey: ApiKeyConfig) {
        if quotas[apiKey.id] == nil {
            quotas[apiKey.id] = .loading
        }
    }
}
