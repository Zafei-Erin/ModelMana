//
//  ClaudeCredentialType.swift
//  ModelMana
//
//  Created by refactoring from AppState.swift
//

import Foundation

/// Represents the type of Claude credential being used
enum ClaudeCredentialType: Equatable, Codable {
    case manualKey(String)  // apiKeyId
    case subscription
    case console
}
