//
//  AppState.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//  Refactored: 2025-01-17
//

import SwiftUI

@Observable
class AppState {
    static let shared = AppState()

    // MARK: - Configuration

    var configuration: AppConfiguration

    // MARK: - Quota State

    /// API Key quota info (key is apiKeyId)
    var apiKeyQuotas: [String: ApiKeyQuota] = [:]

    // MARK: - Claude Login State

    /// Claude login state
    var claudeLoginState: ClaudeLoginState = ClaudeLoginState()

    /// Track which Claude credential type is currently selected
    var selectedClaudeCredential: ClaudeCredentialType? = nil

    /// Track subscription usage (for display in dropdown)
    var subscriptionUsage: ClaudeOAuthUsageResponse? = nil

    /// Track subscription login status separately
    var isSubscriptionLoggedIn: Bool = false

    // MARK: - Claude Console Cost State

    /// Claude Console cost metrics
    var claudeConsoleMetrics: ClaudeConsoleMetricsResponse?

    /// Cost loading state
    var costLoadingState: CostLoadingState = .idle

    /// Last cost update timestamp
    var lastCostUpdate: Date?

    // MARK: - Timers

    var quotaTimer: Timer?
    var costTimer: Timer?

    // MARK: - Initialization

    private init() {
        configuration = ConfigService.loadConfiguration()

        // Initialize all apikeys as failed to fetch
        for provider in configuration.providers {
            for apiKey in provider.apiKeys {
                apiKeyQuotas[apiKey.id] = ApiKeyQuota(status: .error("failed to fetch"))
            }
        }

        // Immediately fetch quotas on launch
        refreshAllQuotas()

        // Try to fetch Claude Console cost on launch
        refreshClaudeConsoleCost()

        // Start auto-refresh timers (every 10 minutes)
        startQuotaRefreshTimer()
        startCostTimer()
    }

    // MARK: - Deinitialization

    deinit {
        quotaTimer?.invalidate()
        costTimer?.invalidate()
    }

    // MARK: - Quota Refresh

    /// Refresh quotas for all providers
    func refreshAllQuotas() {
        refreshZhipuQuotas()
        // Add other provider quota refresh here in the future
    }

    /// Start quota refresh timer (every 10 minutes)
    func startQuotaRefreshTimer() {
        quotaTimer?.invalidate()

        quotaTimer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { [weak self] _ in
            self?.refreshAllQuotas()
        }
    }
}
