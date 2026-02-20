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
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshSubscriptionUsage() }
            group.addTask { await self.refreshConsoleCost() }
            group.addTask { await self.refreshApiKeysQuota() }
        }
    }

    var hasCustomDropdownPanel: Bool { true }

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
        } catch let err as ClaudeOAuthFetchError {
            // Log detailed error info
            switch err {
            case .serverError(let code, let body):
                if let body = body {
                    Logger.error("Claude", "Subscription: HTTP \(code) - \(body)")
                } else {
                    Logger.error("Claude", "Subscription: HTTP \(code)")
                }
            case .networkError(let netErr):
                Logger.error("Claude", "Subscription: Network - \(netErr)")
            default:
                Logger.error("Claude", "Subscription: \(err.localizedDescription)")
            }
        } catch {
            Logger.error("Claude", "Subscription: \(error)")
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
            switch apiErr {
            case .httpError(let code, let body):
                if let body = body {
                    Logger.error("Claude", "Console: HTTP \(code) - \(body)")
                } else {
                    Logger.error("Claude", "Console: HTTP \(code)")
                }
            case .networkError(let netErr):
                // Skip logging cancelled errors (expected during refresh)
                let nsErr = netErr as NSError
                if nsErr.domain == NSURLErrorDomain, nsErr.code == NSURLErrorCancelled {
                    // Request was cancelled, likely due to refresh - don't log
                } else {
                    Logger.error("Claude", "Console: Network - \(netErr)")
                }
            default:
                Logger.error("Claude", "Console: \(apiErr.localizedDescription)")
            }
            costLoadingState = .error(apiErr.localizedDescription)
        } catch {
            Logger.error("Claude", "Console: Unknown - \(error)")
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
