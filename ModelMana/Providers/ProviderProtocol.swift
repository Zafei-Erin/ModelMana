//
//  ProviderProtocol.swift
//  ModelMana
//
//  Provider abstraction for modular provider implementations
//

import Foundation
import SwiftUI

// MARK: - AIProvider Protocol

/// Protocol defining the interface for all AI provider implementations
@MainActor
protocol AIProvider: Observable, Identifiable {
    /// Unique provider identifier
    var id: String { get }

    /// Display name
    var name: String { get }

    /// Provider configuration (reference to AppConfiguration data)
    var config: ProviderConfig { get }

    /// Refresh usage data for this provider
    func refreshUsage() async

    /// Whether this provider has a custom dropdown panel
    var hasCustomDropdownPanel: Bool { get }

    /// Get the dropdown panel view for this provider
    func makeDropdownPanel() -> any View

    /// Get provider-specific settings view (optional)
    func makeSettingsView() -> (any View)?

    /// Additional dropdown content rendered below API key list (optional)
    func makeAdditionalDropdownContent() -> (any View)?

    /// Get current usage percentage for menu bar icon (0-100, nil if unavailable)
    var usagePercentage: Double? { get }
}

// MARK: - Default Implementations

extension AIProvider {
    func makeAdditionalDropdownContent() -> (any View)? { nil }

    var usagePercentage: Double? { nil }
}
