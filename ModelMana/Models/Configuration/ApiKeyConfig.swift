//
//  ApiKeyConfig.swift
//  ModelMana
//
//  Created by refactoring from ProviderConfig.swift
//

import Foundation

/// API Key configuration
struct ApiKeyConfig: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var key: String

    init(id: String = UUID().uuidString, name: String, key: String) {
        self.id = id
        self.name = name
        self.key = key
    }

    /// Masked key for display purposes
    var maskedKey: String {
        if key.count <= 8 { return String(repeating: "•", count: key.count) }
        return "\(key.prefix(4))•••\(key.suffix(4))"
    }
}
