//
//  AppState.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import SwiftUI

// MARK: - Claude Credential Type

enum ClaudeCredentialType: Equatable {
    case manualKey(String)  // apiKeyId
    case subscription
    case console
}

@Observable
class AppState {
    static let shared = AppState()

    var configuration: AppConfiguration

    // API Key 配额信息 (key 为 apiKeyId)
    var apiKeyQuotas: [String: ApiKeyQuota] = [:]

    // Claude 登录状态
    var claudeLoginState: ClaudeLoginState = ClaudeLoginState()

    // Claude Console 成本追踪状态
    var claudeConsoleMetrics: ClaudeConsoleMetricsResponse?
    var costLoadingState: CostLoadingState = .idle
    var lastCostUpdate: Date?

    // Track which Claude credential type is currently selected
    var selectedClaudeCredential: ClaudeCredentialType? = nil

    // Track subscription usage (for display in dropdown)
    var subscriptionUsage: ClaudeOAuthUsageResponse? = nil

    // Track subscription login status separately
    var isSubscriptionLoggedIn: Bool = false

    private var quotaTimer: Timer?
    private var costTimer: Timer?

    private init() {
        configuration = ConfigService.loadConfiguration()

        // 初始化所有 apikey 为 failed to fetch
        for provider in configuration.providers {
            for apiKey in provider.apiKeys {
                apiKeyQuotas[apiKey.id] = ApiKeyQuota(status: .error("failed to fetch"))
            }
        }

        // 启动时立即获取 Zhipu 配额
        refreshAllZhipuQuotas()

        // 启动时尝试获取 Claude Console 成本
        refreshClaudeConsoleCost()

        // 每 10 分钟自动刷新
        startQuotaTimer()
        startCostTimer()
    }

    /// 获取指定 API Key 的配额信息
    func getQuota(for apiKeyId: String) -> ApiKeyQuota {
        apiKeyQuotas[apiKeyId]!  // 一定存在，因为已预初始化
    }

    /// 注册新的 API Key（添加时调用）
    func registerApiKey(_ apiKeyId: String) {
        if apiKeyQuotas[apiKeyId] == nil {
            apiKeyQuotas[apiKeyId] = ApiKeyQuota(status: .error("failed to fetch"))
        }
    }

    /// 查询单个 Zhipu API Key 的配额
    func fetchZhipuQuota(apiKey: String, apiKeyId: String) {
        // 先设置为 loading 状态
        apiKeyQuotas[apiKeyId] = ApiKeyQuota(status: .loading)

        print("[AppState] 开始获取配额: apiKeyId=\(apiKeyId.prefix(8))...")

        ZhipuQuotaService.fetchQuota(apiKey: apiKey) { [self] result in
            Task { @MainActor in
                switch result {
                case .success(let data):
                    print("[AppState] 配额获取成功: \(apiKeyId.prefix(8))..., \(data.percentage)%")
                    self.apiKeyQuotas[apiKeyId] = ApiKeyQuota(
                        status: .success(percentage: data.percentage, nextResetTime: data.nextResetTime)
                    )
                case .failure(let error):
                    print("[AppState] 配额获取失败: \(apiKeyId.prefix(8))..., 错误: \(error.localizedDescription)")
                    self.apiKeyQuotas[apiKeyId] = ApiKeyQuota(status: .error(error.localizedDescription))
                }
            }
        }
    }

    /// 刷新所有 Zhipu provider 的 API Key 配额
    func refreshAllZhipuQuotas() {
        // 找到所有 zhipu provider 的 API keys
        for provider in configuration.providers {
            if provider.id == "zhipu" {
                for apiKey in provider.apiKeys {
                    fetchZhipuQuota(apiKey: apiKey.key, apiKeyId: apiKey.id)
                }
            }
        }
    }

    /// 启动定时器，每 10 分钟刷新一次配额
    private func startQuotaTimer() {
        quotaTimer?.invalidate()

        quotaTimer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { [weak self] _ in
            self?.refreshAllZhipuQuotas()
        }
    }

    deinit {
        quotaTimer?.invalidate()
        costTimer?.invalidate()
    }

    // MARK: - Claude Login

    /// 启动 Claude 登录
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

    /// 刷新 Claude Console 成本数据
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

    /// 启动成本数据定时器（每 10 分钟刷新一次）
    private func startCostTimer() {
        costTimer?.invalidate()

        costTimer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { [weak self] _ in
            self?.refreshClaudeConsoleCost()
        }
    }
}

// MARK: - Cost Loading State

enum CostLoadingState: Equatable {
    case idle
    case loading
    case success
    case error(String)

    static func == (lhs: CostLoadingState, rhs: CostLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.success, .success):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
