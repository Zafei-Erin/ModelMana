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

    var apiKeyQuotas: [String: QuotaState] = [:]

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
            apiKeyQuotas[key.id] = .loading
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

    var hasCustomDropdownPanel: Bool { false }

    /// Get current usage percentage for menu bar icon
    /// Only subscription has percentage; API key and console return nil (show default icon)
    var usagePercentage: Double? {
        switch selectedCredential {
        case .subscription:
            return subscriptionUsage?.fiveHour?.utilization
        case .manualKey, .console, .none:
            return nil
        }
    }

    func makeDropdownPanel() -> any View {
        ClaudeProviderPanel(provider: self)
    }

    func makeSettingsView() -> (any View)? {
        nil  // Uses generic settings view
    }

    func makeAdditionalDropdownContent() -> (any View)? {
        ClaudeAdditionalEntries(provider: self)
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
        // Claude API keys don't support usage queries
        // Return empty loaded state to suppress any display
        apiKeyQuotas[apiKey.id] = .loaded([])
    }

    func quota(for apiKeyId: String) -> QuotaState {
        apiKeyQuotas[apiKeyId] ?? .loaded([])
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
            apiKeyQuotas[apiKey.id] = .loading
        }
    }
}

// MARK: - Claude Additional Dropdown Entries

struct ClaudeAdditionalEntries: View {
    @ObservedProvider private var provider: ClaudeProvider

    init(provider: ClaudeProvider) {
        self.provider = provider
    }

    private var isSubscriptionLoggedIn: Bool {
        AppState.shared.isSubscriptionLoggedIn
    }

    var body: some View {
        subscriptionEntry
        Divider().padding(.horizontal, 6)
        consoleEntry
    }

    // MARK: - Subscription

    private var subscriptionEntry: some View {
        CredentialEntryLayout(
            title: "Subscription",
            isSelected: provider.selectedCredential == .subscription,
            action: { provider.startLogin(method: .subscription) }
        ) {
            if (provider.loginState.isProcessing && provider.loginState.method == .subscription)
                || provider.isSubscriptionLoading {
                ProgressView()
                    .scaleEffect(0.3)
                    .frame(height: 12)
            } else {
                if !isSubscriptionLoggedIn {
                    Text("Login to use your subscription \(Image(systemName: "arrow.up.right"))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if let usage = provider.subscriptionUsage?.fiveHour?.utilization {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        ProgressView(value: usage / 100, total: 1.0)
                            .progressViewStyle(BlackProgressStyle())
                        Text("\(Int(usage))%")
                            .font(.system(size: 9))
                    }
                    .frame(height: 12)
                } else if isSubscriptionLoggedIn {
                    Text("Failed to fetch")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Console

    private var consoleEntry: some View {
        CredentialEntryLayout(
            title: "Console",
            isSelected: provider.selectedCredential == .console,
            action: { provider.startLogin(method: .console) }
        ) {
            if (provider.loginState.isProcessing && provider.loginState.method == .console)
                || provider.isConsoleLoading {
                ProgressView()
                    .scaleEffect(0.3)
                    .frame(height: 12)
            } else {
                if !ClaudeSessionService.isConsoleLoggedIn() {
                    Text("Login to use console api \(Image(systemName: "arrow.up.right"))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if let metrics = provider.consoleMetrics {
                    Text("This month: \(metrics.formattedCost)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else if case .error = provider.costLoadingState {
                    Text("Failed to fetch")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
