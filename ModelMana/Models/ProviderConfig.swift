//
//  ProviderConfig.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import Foundation

/// API Key 配置
struct ApiKeyConfig: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var key: String

    init(id: String = UUID().uuidString, name: String, key: String) {
        self.id = id
        self.name = name
        self.key = key
    }

    // 显示用（遮罩）
    var maskedKey: String {
        if key.count <= 8 { return String(repeating: "•", count: key.count) }
        return "\(key.prefix(4))•••\(key.suffix(4))"
    }
}

/// 单个 Provider 的配置
struct ProviderConfig: Codable, Identifiable {
    let id: String
    let name: String
    let baseUrl: String
    var apiKeys: [ApiKeyConfig]

    init(id: String, name: String, baseUrl: String, apiKeys: [ApiKeyConfig]) {
        self.id = id
        self.name = name
        self.baseUrl = baseUrl
        self.apiKeys = apiKeys
    }

    // 向后兼容：从旧的 apiKey 字段迁移
    init(id: String, name: String, baseUrl: String, apiKey: String) {
        self.id = id
        self.name = name
        self.baseUrl = baseUrl
        self.apiKeys = apiKey.isEmpty ? [] : [ApiKeyConfig(name: "Default", key: apiKey)]
    }
}

/// 应用配置
struct AppConfiguration: Codable {
    var providers: [ProviderConfig]
    var selectedProviderId: String?
    var selectedApiKeyId: String?  // 全局选中的 API Key id

    // 获取当前选中的 Provider 配置
    var currentProvider: ProviderConfig? {
        guard let selectedId = selectedProviderId else { return nil }
        return providers.first { $0.id == selectedId }
    }

    // 获取当前选中的 API Key 配置（全局）
    var currentApiKeyConfig: ApiKeyConfig? {
        guard let selectedId = selectedApiKeyId else { return nil }
        for provider in providers {
            if let keyConfig = provider.apiKeys.first(where: { $0.id == selectedId }) {
                return keyConfig
            }
        }
        return nil
    }

    // 获取当前选中的 API Key（全局）
    var currentApiKey: String? {
        return currentApiKeyConfig?.key
    }

    init(providers: [ProviderConfig], selectedProviderId: String?, selectedApiKeyId: String? = nil) {
        self.providers = providers
        self.selectedProviderId = selectedProviderId
        self.selectedApiKeyId = selectedApiKeyId
    }
}
