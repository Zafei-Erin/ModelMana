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

    /// Get the dropdown panel view for this provider
    func makeDropdownPanel() -> any View

    /// Get provider-specific settings view (optional)
    func makeSettingsView() -> (any View)?
}
