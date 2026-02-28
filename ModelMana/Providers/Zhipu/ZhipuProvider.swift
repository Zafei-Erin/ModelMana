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

    /// Get current usage percentage from selected API key's quota (5h session)
    var usagePercentage: Double? {
        let selectedKeyId = ProviderRegistry.shared.configuration.selectedApiKeyId
        guard let selectedKeyId = selectedKeyId,
              !selectedKeyId.isEmpty,
              case .loaded(let items) = quota(for: selectedKeyId) else {
            // Fallback: get first available quota
            return firstAvailableQuotaPercentage
        }
        // Get Session (5h) quota
        return items.first(where: { $0.title.contains("5h") })?.percentage
    }

    /// Get first available quota percentage as fallback
    private var firstAvailableQuotaPercentage: Double? {
        for key in config.apiKeys {
            if case .loaded(let items) = quota(for: key.id) {
                if let sessionQuota = items.first(where: { $0.title.contains("5h") }),
                   let percentage = sessionQuota.percentage {
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

        let result = await ZhipuQuotaService.fetchQuota(apiKey: apiKey.key)

        switch result {
        case .success(let items):
            Logger.log("Zhipu", "Quota: \(items.compactMap { $0.percentage }.map { "\(Int($0))%" }.joined(separator: ", "))")
            quotas[apiKey.id] = .loaded(items)
        case .failure(let error):
            Logger.error("Zhipu", error.localizedDescription)
            quotas[apiKey.id] = .loaded([
                QuotaItem(title: "Session (5h)", status: .error(error.localizedDescription)),
                QuotaItem(title: "MCP", status: .error(error.localizedDescription))
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
