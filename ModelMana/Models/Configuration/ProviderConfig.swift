//
//  ProviderConfig.swift
//  ModelMana
//
//  Created by refactoring from ProviderConfig.swift
//

import Foundation

/// Model name overrides for a provider
struct ModelConfig: Codable, Equatable {
    var opusModel: String?
    var sonnetModel: String?
    var haikuModel: String?
    var subagentModel: String?

    var isEmpty: Bool {
        [opusModel, sonnetModel, haikuModel, subagentModel].allSatisfy { ($0 ?? "").isEmpty }
    }
}

/// Single provider configuration
struct ProviderConfig: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let baseUrl: String
    var apiKeys: [ApiKeyConfig]
    var modelConfig: ModelConfig?

    init(id: String, name: String, baseUrl: String, apiKeys: [ApiKeyConfig], modelConfig: ModelConfig? = nil) {
        self.id = id
        self.name = name
        self.baseUrl = baseUrl
        self.apiKeys = apiKeys
        self.modelConfig = modelConfig
    }

    /// Backward compatibility: migrate from old apiKey field
    init(id: String, name: String, baseUrl: String, apiKey: String) {
        self.id = id
        self.name = name
        self.baseUrl = baseUrl
        self.apiKeys = apiKey.isEmpty ? [] : [ApiKeyConfig(name: "Default", key: apiKey)]
        self.modelConfig = nil
    }
}
