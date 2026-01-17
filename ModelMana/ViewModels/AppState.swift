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

    private var dataRefreshTimer: Timer?

    // MARK: - Initialization

    private init() {
        configuration = ConfigService.loadConfiguration()

        // Initialize all apikeys as failed to fetch
        for provider in configuration.providers {
            for apiKey in provider.apiKeys {
                apiKeyQuotas[apiKey.id] = ApiKeyQuota(status: .error("failed to fetch"))
            }
        }

        // Immediately fetch all data on launch
        refreshAllData()

        // Start auto-refresh timer (every 10 minutes)
        startDataRefreshTimer()
    }

    // MARK: - Deinitialization

    deinit {
        dataRefreshTimer?.invalidate()
    }

    // MARK: - Data Refresh

    /// Refresh all data (quotas, costs, etc.)
    func refreshAllData() {
        refreshZhipuQuotas()
        refreshClaudeConsoleCost()
        // Add more data refresh here in the future
    }

    /// Start data refresh timer (every 10 minutes)
    func startDataRefreshTimer() {
        dataRefreshTimer?.invalidate()

        dataRefreshTimer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) {
            [weak self] _ in
            self?.refreshAllData()
        }
    }
}
