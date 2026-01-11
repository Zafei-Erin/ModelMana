//
//  AppState.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import SwiftUI

@Observable
class AppState {
    static let shared = AppState()

    var configuration: AppConfiguration

    // API Key 配额信息 (key 为 apiKeyId)
    var apiKeyQuotas: [String: ApiKeyQuota] = [:]

    private var quotaTimer: Timer?

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

        // 每 10 分钟自动刷新
        startQuotaTimer()
    }

    /// 获取指定 API Key 的配额信息
    func getQuota(for apiKeyId: String) -> ApiKeyQuota {
        apiKeyQuotas[apiKeyId]!  // 一定存在，因为已预初始化
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
    }
}
