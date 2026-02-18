//
//  ProviderConfig.swift
//  ModelMana
//
//  Created by refactoring from ProviderConfig.swift
//

import Foundation

/// Single provider configuration
struct ProviderConfig: Codable, Identifiable, Equatable {
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

    /// Backward compatibility: migrate from old apiKey field
    init(id: String, name: String, baseUrl: String, apiKey: String) {
        self.id = id
        self.name = name
        self.baseUrl = baseUrl
        self.apiKeys = apiKey.isEmpty ? [] : [ApiKeyConfig(name: "Default", key: apiKey)]
    }
}
