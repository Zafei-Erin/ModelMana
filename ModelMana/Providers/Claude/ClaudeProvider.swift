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
    var selectedCredential: ClaudeCredentialType?

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

    private func refreshSubscriptionUsage() async {
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

    private func refreshConsoleCost() async {
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
                Logger.log("Claude", "Console: No data")
            }
        } catch ClaudeCookieError.noBrowserFound {
            Logger.log("Claude", "Console: No browser cookies")
        } catch {
            Logger.error("Claude", "Console: \(error.localizedDescription)")
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

    /// Start Claude login
    func startLogin(method: ClaudeLoginMethod) {
        loginState = ClaudeLoginState(phase: .requesting, method: method)

        Task {
            do {
                try await ClaudeLoginService.shared.startLogin(method: method) { [self] newPhase in
                    Task { @MainActor in
                        loginState.phase = newPhase
                    }
                }

                Task { @MainActor in
                    loginState.phase = .success
                    Logger.success("Claude", "Logged in via \(method.displayName)")

                    switch method {
                    case .subscription:
                        selectedCredential = .subscription
                        isSubscriptionLoggedIn = true
                        ProviderRegistry.shared.selectProvider(id)
                        ProviderRegistry.shared.selectApiKey("")

                        do {
                            let usage = try await ClaudeSessionService.refreshUsage()
                            subscriptionUsage = usage
                        } catch {
                            Logger.error("Claude", "Failed to fetch usage")
                        }

                    case .console:
                        selectedCredential = .console
                        ProviderRegistry.shared.selectProvider(id)
                        ProviderRegistry.shared.selectApiKey("")

                        await refreshConsoleCost()
                    }

                    try? SettingsFileService.writeKeychainAuthSettings()
                }
            } catch let error as ClaudeLoginError {
                Task { @MainActor in
                    loginState.phase = .failed(error.localizedDescription)
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
