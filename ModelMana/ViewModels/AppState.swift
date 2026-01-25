//
//  AppState.swift
//  ModelMana
//
//  Refactored to use ProviderRegistry
//

import SwiftUI

@MainActor
@Observable
class AppState {
    static let shared = AppState()

    // MARK: - Configuration

    /// Application configuration - delegates to ProviderRegistry
    var configuration: AppConfiguration {
        get { ProviderRegistry.shared.configuration }
        set { ProviderRegistry.shared.configuration = newValue }
    }

    // MARK: - Quota State (delegated to providers)

    /// API Key quota info (key is apiKeyId) - aggregated from providers
    var apiKeyQuotas: [String: ApiKeyQuota] {
        var result: [String: ApiKeyQuota] = [:]

        for provider in ProviderRegistry.shared.allProviders {
            if let zhipu = provider as? ZhipuProvider {
                result.merge(zhipu.quotas) { _, new in new }
            }
            if let minimax = provider as? MinimaxProvider {
                result.merge(minimax.quotas) { _, new in new }
            }
            if let claude = provider as? ClaudeProvider {
                result.merge(claude.apiKeyQuotas) { _, new in new }
            }
        }

        return result
    }

    // MARK: - Claude State (delegated to ClaudeProvider)

    /// Claude login state
    var claudeLoginState: ClaudeLoginState {
        get { ProviderRegistry.shared.claude.loginState }
        set { ProviderRegistry.shared.claude.loginState = newValue }
    }

    /// Selected Claude credential type
    var selectedClaudeCredential: ClaudeCredentialType? {
        get { ProviderRegistry.shared.claude.selectedCredential }
        set { ProviderRegistry.shared.claude.selectedCredential = newValue }
    }

    /// Subscription usage data
    var subscriptionUsage: ClaudeOAuthUsageResponse? {
        ProviderRegistry.shared.claude.subscriptionUsage
    }

    /// Subscription login status
    var isSubscriptionLoggedIn: Bool {
        ClaudeSessionService.isLoggedIn()
    }

    /// Claude Console cost metrics
    var claudeConsoleMetrics: ClaudeConsoleMetricsResponse? {
        ProviderRegistry.shared.claude.consoleMetrics
    }

    /// Cost loading state
    var costLoadingState: CostLoadingState {
        get { ProviderRegistry.shared.claude.costLoadingState }
        set { ProviderRegistry.shared.claude.costLoadingState = newValue }
    }

    /// Last cost update timestamp
    var lastCostUpdate: Date? {
        ProviderRegistry.shared.claude.lastConsoleUpdate
    }

    // MARK: - Initialization

    private init() {
        // ProviderRegistry is initialized lazily on first access
    }

    // MARK: - Data Refresh (delegated to ProviderRegistry)

    /// Refresh all data (quotas, costs, etc.)
    func refreshAllData() {
        Task {
            await ProviderRegistry.shared.refreshAll()
        }
    }

    /// Start data refresh timer (delegated to ProviderRegistry)
    func startDataRefreshTimer() {
        // Timer is managed by ProviderRegistry
    }

    // MARK: - Quota Helpers

    /// Get quota for specified API Key
    func getQuota(for apiKeyId: String) -> ApiKeyQuota {
        let zhipuQuota = ProviderRegistry.shared.zhipu.quota(for: apiKeyId)
        if case .error = zhipuQuota.status {
            let minimaxQuota = ProviderRegistry.shared.minimax.quota(for: apiKeyId)
            if case .error = minimaxQuota.status {
                return ProviderRegistry.shared.claude.quota(for: apiKeyId)
            }
            return minimaxQuota
        }
        return zhipuQuota
    }

    /// Register new API Key (called when adding)
    func registerApiKey(_ apiKeyId: String) {
        for provider in ProviderRegistry.shared.allProviders {
            if let zhipu = provider as? ZhipuProvider,
               zhipu.config.apiKeys.contains(where: { $0.id == apiKeyId }) {
                if let key = zhipu.config.apiKeys.first(where: { $0.id == apiKeyId }) {
                    zhipu.registerApiKey(key)
                }
                return
            }
            if let minimax = provider as? MinimaxProvider,
               minimax.config.apiKeys.contains(where: { $0.id == apiKeyId }) {
                if let key = minimax.config.apiKeys.first(where: { $0.id == apiKeyId }) {
                    minimax.registerApiKey(key)
                }
                return
            }
            if let claude = provider as? ClaudeProvider,
               claude.config.apiKeys.contains(where: { $0.id == apiKeyId }) {
                if let key = claude.config.apiKeys.first(where: { $0.id == apiKeyId }) {
                    claude.registerApiKey(key)
                }
                return
            }
        }
    }

    // MARK: - Zhipu Quota Management (delegated to ZhipuProvider)

    /// Fetch quota for single Zhipu API Key
    func fetchZhipuQuota(apiKey: String, apiKeyId: String) {
        Task {
            await ProviderRegistry.shared.zhipu.refreshUsage()
        }
    }

    /// Refresh Zhipu API Key quotas
    func refreshZhipuQuotas() {
        Task {
            await ProviderRegistry.shared.zhipu.refreshUsage()
        }
    }

    // MARK: - Claude Login (delegated to ClaudeProvider)

    /// Start Claude login
    func startClaudeLogin(method: ClaudeLoginMethod) {
        print("[AppState] startClaudeLogin called with method: \(method.displayName)")
        ProviderRegistry.shared.claude.startLogin(method: method)
    }

    // MARK: - Claude Console Cost (delegated to ClaudeProvider)

    /// Refresh Claude Console cost data
    func refreshClaudeConsoleCost() {
        Task {
            await ProviderRegistry.shared.claude.refreshUsage()
        }
    }
}
