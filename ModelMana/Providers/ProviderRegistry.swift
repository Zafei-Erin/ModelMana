//
//  ProviderRegistry.swift
//  ModelMana
//
//  Central registry for managing all providers
//

import Foundation
import SwiftUI

/// Central registry that holds all provider instances and manages auto-refresh
@MainActor
@Observable
class ProviderRegistry {
    // MARK: - Singleton

    static let shared = ProviderRegistry()

    // MARK: - Configuration (source of truth)

    /// Application configuration - when modified, saves to disk
    var configuration: AppConfiguration {
        didSet {
            // Only reload providers when providers list changes (add/remove/modify API keys)
            if configuration.providers != oldValue.providers {
                reloadProviders()
            }
            // Persist to disk
            try? ConfigService.saveConfiguration(configuration)
        }
    }

    // MARK: - Providers

    private(set) var claude: ClaudeProvider!
    private(set) var zhipu: ZhipuProvider!
    private(set) var minimax: MinimaxProvider!

    /// All providers as Provider protocol
    var allProviders: [any AIProvider] {
        [claude, zhipu, minimax]
    }

    /// Currently selected provider
    var selectedProvider: (any AIProvider)? {
        guard let selectedId = configuration.selectedProviderId else { return nil }
        return allProviders.first { $0.id == selectedId }
    }

    /// Current usage percentage for menu bar icon (0-100, nil if unavailable)
    var currentUsagePercentage: Double? {
        selectedProvider?.usagePercentage
    }

    /// Check if any provider is currently loading
    var isAnyProviderLoading: Bool {
        claude.isSubscriptionLoading || claude.isConsoleLoading
    }

    // MARK: - Timer

    private var refreshTimer: Timer?

    // MARK: - Initialization

    private init() {
        // Load configuration from disk
        configuration = ConfigService.loadConfiguration()

        // Create providers from configuration
        reloadProviders()

        // Initial refresh
        Task {
            await refreshAll()
        }

        // Start auto-refresh timer (every 10 minutes)
        startRefreshTimer()
    }

    // MARK: - Provider Management

    private func reloadProviders() {
        claude = ClaudeProvider(
            config: configuration["claude"] ?? ProviderConfig(
                id: "claude",
                name: "Claude",
                baseUrl: "https://api.anthropic.com",
                apiKeys: []
            )
        )

        zhipu = ZhipuProvider(
            config: configuration["zhipu"] ?? ProviderConfig(
                id: "zhipu",
                name: "Zhipu",
                baseUrl: "https://open.bigmodel.cn/api/anthropic",
                apiKeys: []
            )
        )

        minimax = MinimaxProvider(
            config: configuration["minimax"] ?? ProviderConfig(
                id: "minimax",
                name: "Minimax",
                baseUrl: "https://api.minimaxi.com/anthropic",
                apiKeys: []
            )
        )
    }

    // MARK: - Refresh

    /// Refresh usage data for all providers in parallel
    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.claude.refreshUsage() }
            group.addTask { await self.zhipu.refreshUsage() }
            group.addTask { await self.minimax.refreshUsage() }
        }

        // Trigger icon update after refresh
        AppState.shared.iconUpdateTrigger += 1
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAll()
            }
        }
    }

    // MARK: - Helpers

    /// Get provider by ID
    func provider(withId id: String) -> (any AIProvider)? {
        allProviders.first { $0.id == id }
    }

    /// Update the selected provider
    func selectProvider(_ providerId: String) {
        configuration.selectedProviderId = providerId
    }

    /// Update the selected API key
    func selectApiKey(_ apiKeyId: String) {
        configuration.selectedApiKeyId = apiKeyId
    }

    /// Invalidate timer (call before cleanup)
    func invalidateTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
