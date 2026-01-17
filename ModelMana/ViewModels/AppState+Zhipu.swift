//
//  AppState+Zhipu.swift
//  ModelMana
//
//  Created by refactoring from AppState.swift
//

import SwiftUI

extension AppState {
    // MARK: - Zhipu Quota Management

    /// Get quota for specified API Key
    func getQuota(for apiKeyId: String) -> ApiKeyQuota {
        apiKeyQuotas[apiKeyId]!  // Always exists due to pre-initialization
    }

    /// Register new API Key (called when adding)
    func registerApiKey(_ apiKeyId: String) {
        if apiKeyQuotas[apiKeyId] == nil {
            apiKeyQuotas[apiKeyId] = ApiKeyQuota(status: .error("failed to fetch"))
        }
    }

    /// Fetch quota for single Zhipu API Key
    func fetchZhipuQuota(apiKey: String, apiKeyId: String) {
        // Set to loading state first
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

    /// Refresh all Zhipu provider API Key quotas
    func refreshAllZhipuQuotas() {
        // Find all zhipu provider API keys
        for provider in configuration.providers {
            if provider.id == "zhipu" {
                for apiKey in provider.apiKeys {
                    fetchZhipuQuota(apiKey: apiKey.key, apiKeyId: apiKey.id)
                }
            }
        }
    }

    /// Start quota timer (refresh every 10 minutes)
    func startQuotaTimer() {
        quotaTimer?.invalidate()

        quotaTimer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { [weak self] _ in
            self?.refreshAllZhipuQuotas()
        }
    }
}
