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
    }

    // MARK: - Provider Protocol

    func refreshUsage() async {
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
        // Only refresh if subscription is the selected credential
        guard selectedCredential == .subscription else { return }

        isSubscriptionLoading = true
        defer { isSubscriptionLoading = false }

        do {
            let usage = try await ClaudeSessionService.refreshUsage()
            subscriptionUsage = usage
            lastSubscriptionUpdate = Date()
        } catch {
            print("[ClaudeProvider] Failed to refresh subscription usage: \(error)")
        }
    }

    // MARK: - Console

    private func refreshConsoleCost() async {
        // Only refresh if console is the selected credential
        guard selectedCredential == .console else { return }

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
        } catch {
            print("[ClaudeProvider] Failed to refresh console cost: \(error)")
            costLoadingState = .error(error.localizedDescription)
        }
    }

    // MARK: - API Keys

    private func refreshApiKeysQuota() async {
        // Only refresh if an API key is selected
        guard case .manualKey = selectedCredential else { return }

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
        print("[ClaudeProvider] startLogin called with method: \(method.displayName)")

        loginState = ClaudeLoginState(phase: .requesting, method: method)

        Task {
            do {
                print("[ClaudeProvider] About to call ClaudeLoginService.shared.startLogin")
                try await ClaudeLoginService.shared.startLogin(method: method) { [self] newPhase in
                    print("[ClaudeProvider] Phase changed to: \(newPhase)")
                    Task { @MainActor in
                        loginState.phase = newPhase
                    }
                }
                print("[ClaudeProvider] startLogin completed, checking if logged in")

                Task { @MainActor in
                    loginState.phase = .success
                    print("[ClaudeProvider] Login phase set to success")

                    switch method {
                    case .subscription:
                        selectedCredential = .subscription
                        ProviderRegistry.shared.selectProvider(id)
                        ProviderRegistry.shared.selectApiKey("")  // No API key for subscription

                        // Fetch usage
                        do {
                            print("[ClaudeProvider] Fetching subscription usage...")
                            let usage = try await ClaudeSessionService.refreshUsage()
                            subscriptionUsage = usage
                            print("[ClaudeProvider] Subscription usage fetched")
                        } catch {
                            print("[ClaudeProvider] Failed to fetch subscription usage: \(error)")
                        }

                    case .console:
                        selectedCredential = .console
                        ProviderRegistry.shared.selectProvider(id)
                        ProviderRegistry.shared.selectApiKey("")  // No API key for console

                        // Refresh console cost
                        print("[ClaudeProvider] Refreshing console cost...")
                        await refreshConsoleCost()
                        print("[ClaudeProvider] Console cost refreshed")
                    }

                    // Write keychain auth settings
                    try? SettingsFileService.writeKeychainAuthSettings()
                    print("[ClaudeProvider] Keychain settings written")
                }
            } catch let error as ClaudeLoginError {
                print("[ClaudeProvider] Login error (ClaudeLoginError): \(error)")
                Task { @MainActor in
                    loginState.phase = .failed(error.localizedDescription)
                }
            } catch {
                print("[ClaudeProvider] Login error (general): \(error.localizedDescription)")
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
