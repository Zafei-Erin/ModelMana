//
//  ClaudeProvider.swift
//  ModelMana
//
//  Claude AI provider implementation
//

import Foundation
import SwiftUI

/// Claude provider - supports subscription OAuth, console login, and API keys
@MainActor
@Observable
class ClaudeProvider: AIProvider {
    let id = "claude"
    let name = "Claude"
    let config: ProviderConfig

    // MARK: - Subscription State

    var subscriptionUsage: ClaudeOAuthUsageResponse?
    var isSubscriptionLoading: Bool = false
    var lastSubscriptionUpdate: Date?
    var isSubscriptionLoggedIn: Bool = false  // Tracked state, not computed

    // MARK: - Console State

    var consoleMetrics: ClaudeConsoleMetricsResponse?
    var isConsoleLoading: Bool = false
    var lastConsoleUpdate: Date?
    var costLoadingState: CostLoadingState = .idle

    // MARK: - API Key State

    var apiKeyQuotas: [String: ApiKeyQuota] = [:]

    // MARK: - Login State

    var loginState: ClaudeLoginState = ClaudeLoginState()

    /// Selected credential type - persisted in configuration
    var selectedCredential: ClaudeCredentialType? {
        get { ProviderRegistry.shared.configuration.selectedClaudeCredential }
        set { ProviderRegistry.shared.configuration.selectedClaudeCredential = newValue }
    }

    init(config: ProviderConfig) {
        self.config = config

        // Initialize quota entries for all API keys
        for key in config.apiKeys {
            apiKeyQuotas[key.id] = ApiKeyQuota(status: .loading)
        }

        // Check initial login status once
        isSubscriptionLoggedIn = ClaudeSessionService.isLoggedIn()
    }

    // MARK: - Provider Protocol

    func refreshUsage() async {
        Logger.log("Claude", "Refreshing...")
        // Refresh all active usage types in parallel
        async let _ = refreshSubscriptionUsage()
        async let _ = refreshConsoleCost()
        async let _ = refreshApiKeysQuota()
    }

    func makeDropdownPanel() -> any View {
        ClaudeProviderPanel(provider: self)
    }

    func makeSettingsView() -> (any View)? {
        nil  // Uses generic settings view
    }

    // MARK: - Subscription

    func refreshSubscriptionUsage() async {
        isSubscriptionLoading = true
        defer { isSubscriptionLoading = false }

        do {
            let usage = try await ClaudeSessionService.refreshUsage()
            subscriptionUsage = usage
            lastSubscriptionUpdate = Date()
            if let utilization = usage.fiveHour?.utilization {
                Logger.log("Claude", "Subscription: \(Int(utilization * 100))%")
            }
        } catch ClaudeOAuthFetchError.credentialsNotFound {
            Logger.log("Claude", "Subscription: Not logged in")
        } catch {
            Logger.error("Claude", "Subscription: \(error.localizedDescription)")
        }
    }

    // MARK: - Console

    func refreshConsoleCost() async {
        Logger.log("Claude", "Console: Refreshing cost...")
        isConsoleLoading = true
        costLoadingState = .loading
        defer {
            isConsoleLoading = false
        }

        do {
            let metrics = try await ClaudeConsoleCostService.fetchCurrentMonthMetrics()
            consoleMetrics = metrics
            costLoadingState = .success
            lastConsoleUpdate = Date()
            if let cost = metrics.totalCost {
                Logger.log("Claude", "Console: $\(String(format: "%.2f", cost))")
            } else {
                Logger.log("Claude", "Console: No cost data")
            }
        } catch let cookieErr as ClaudeCookieError {
            Logger.error("Claude", "Console: Cookie error - \(cookieErr.localizedDescription)")
            costLoadingState = .error(cookieErr.localizedDescription)
        } catch let apiErr as CookieAPIError {
            Logger.error("Claude", "Console: API error - \(apiErr.localizedDescription)")
            costLoadingState = .error(apiErr.localizedDescription)
        } catch {
            Logger.error("Claude", "Console: Unknown error - \(error.localizedDescription)")
            costLoadingState = .error(error.localizedDescription)
        }
    }

    // MARK: - API Keys

    private func refreshApiKeysQuota() async {
        await withTaskGroup(of: Void.self) { group in
            for apiKey in config.apiKeys {
                group.addTask {
                    await self.refreshApiKeyQuota(for: apiKey)
                }
            }
        }
    }

    private func refreshApiKeyQuota(for apiKey: ApiKeyConfig) async {
        // TODO: Implement Claude API key quota checking
        // For now, mark as not implemented
        apiKeyQuotas[apiKey.id] = ApiKeyQuota(status: .error("Not implemented"))
    }

    func quota(for apiKeyId: String) -> ApiKeyQuota {
        apiKeyQuotas[apiKeyId] ?? ApiKeyQuota(status: .error("API key not found"))
    }

    // MARK: - Login

    func startLogin(method: ClaudeLoginMethod) {
        loginState = ClaudeLoginState(phase: .requesting, method: method)

        Task {
            do {
                try await ClaudeLoginService.shared.startLogin(method: method) { [self] newPhase in
                    Task { @MainActor in
                        loginState.phase = newPhase
                    }
                }

                switch method {
                case .subscription:
                    let creds = try ClaudeSessionService.loadCredentials()
                    let usage = try await ClaudeOAuthUsageFetcher.fetchUsage(accessToken: creds.accessToken)
                    ClaudeSessionService.lastUsage = usage

                    Task { @MainActor in
                        loginState.phase = .success
                        selectedCredential = .subscription
                        isSubscriptionLoggedIn = true
                        subscriptionUsage = usage
                        ProviderRegistry.shared.selectProvider(id)
                        ProviderRegistry.shared.selectApiKey("")
                        try? SettingsFileService.writeKeychainAuthSettings()
                    }

                case .console:
                    let metrics = try await ClaudeConsoleCostService.fetchCurrentMonthMetrics()

                    Task { @MainActor in
                        loginState.phase = .success
                        selectedCredential = .console
                        consoleMetrics = metrics
                        costLoadingState = .success
                        lastConsoleUpdate = Date()
                        ProviderRegistry.shared.selectProvider(id)
                        ProviderRegistry.shared.selectApiKey("")
                        try? SettingsFileService.writeKeychainAuthSettings()
                    }
                }
            } catch {
                Task { @MainActor in
                    loginState.phase = .failed(error.localizedDescription)
                }
            }
        }
    }

    /// Register a new API key
    func registerApiKey(_ apiKey: ApiKeyConfig) {
        if apiKeyQuotas[apiKey.id] == nil {
            apiKeyQuotas[apiKey.id] = ApiKeyQuota(status: .loading)
        }
    }
}
