//
//  ProviderConfig.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import Foundation

/// 单个 Provider 的配置
struct ProviderConfig: Codable, Identifiable {
    let id: String
    let name: String
    let baseUrl: String
    let apiKey: String
}

/// 应用配置
struct AppConfiguration: Codable {
    var providers: [ProviderConfig]
    var selectedProviderId: String?
}
