//
//  AppState+Claude.swift
//  ModelMana
//
//  Created by refactoring from AppState.swift
//

import SwiftUI

extension AppState {
    // MARK: - Claude Login

    /// Start Claude login
    func startClaudeLogin(method: ClaudeLoginMethod) {
        print("[AppState] startClaudeLogin called with method: \(method.displayName)")

        // Set initial state
        claudeLoginState = ClaudeLoginState(phase: .requesting, method: method)

        Task {
            do {
                try await ClaudeLoginService.shared.startLogin(method: method) { [self] newPhase in
                    Task { @MainActor in
                        claudeLoginState.phase = newPhase
                    }
                }
                // Success - update state
                Task { @MainActor in
                    claudeLoginState.phase = .success

                    // Set selected credential and update configuration
                    switch method {
                    case .subscription:
                        selectedClaudeCredential = .subscription
                        isSubscriptionLoggedIn = true
                        // Update configuration to reflect Claude as current provider
                        var newConfig = configuration
                        newConfig.selectedProviderId = "claude"
                        newConfig.selectedApiKeyId = nil  // No API key for subscription
                        configuration = newConfig
                        // Save configuration
                        try? ConfigService.saveConfiguration(newConfig)
                        // Fetch usage for display
                        do {
                            let usage = try await ClaudeSessionService.refreshUsage()
                            subscriptionUsage = usage
                        } catch {
                            print("[AppState] Failed to fetch subscription usage: \(error)")
                        }
                    case .console:
                        selectedClaudeCredential = .console
                        // Update configuration to reflect Claude as current provider
                        var newConfig = configuration
                        newConfig.selectedProviderId = "claude"
                        newConfig.selectedApiKeyId = nil  // No API key for console
                        configuration = newConfig
                        // Save configuration
                        try? ConfigService.saveConfiguration(newConfig)
                        // Refresh console cost
                        refreshClaudeConsoleCost()
                    }

                    // Write keychain auth settings
                    try? SettingsFileService.writeKeychainAuthSettings()
                }
                print("[AppState] Login completed successfully")
            } catch {
                print("[AppState] Login error: \(error.localizedDescription)")
                Task { @MainActor in
                    claudeLoginState.phase = .failed(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Claude Console Cost

    /// Refresh Claude Console cost data
    func refreshClaudeConsoleCost() {
        costLoadingState = .loading

        Task { @MainActor in
            do {
                print("[AppState] 开始获取 Claude Console 成本...")
                let metrics = try await ClaudeConsoleCostService.fetchCurrentMonthMetrics()
                self.claudeConsoleMetrics = metrics
                self.costLoadingState = .success
                self.lastCostUpdate = Date()
                print("[AppState] 成本获取成功: \(metrics.formattedCost)")
            } catch {
                print("[AppState] 成本获取失败: \(error.localizedDescription)")
                self.costLoadingState = .error(error.localizedDescription)
            }
        }
    }
}
