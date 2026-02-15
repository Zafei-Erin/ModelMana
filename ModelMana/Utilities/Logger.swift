//
//  Logger.swift
//  ModelMana
//
//  Unified logging utility
//

import Foundation

enum Logger {
    /// Log a message with a module prefix
    /// - Parameters:
    ///   - module: Module name (e.g., "Claude", "Zhipu", "Config")
    ///   - message: Message to log
    static func log(_ module: String, _ message: String) {
        print("[\(module)] \(message)")
    }

    /// Log an error with a module prefix
    /// - Parameters:
    ///   - module: Module name
    ///   - message: Error message
    static func error(_ module: String, _ message: String) {
        print("[\(module)] Error: \(message)")
    }

    /// Log a success message with a module prefix
    /// - Parameters:
    ///   - module: Module name
    ///   - message: Success message
    static func success(_ module: String, _ message: String) {
        print("[\(module)] ✓ \(message)")
    }

    /// Log with a masked value (for sensitive data)
    /// - Parameters:
    ///   - module: Module name
    ///   - message: Message prefix
    ///   - value: Sensitive value to mask
    static func masked(_ module: String, _ message: String, value: String) {
        let masked: String
        if value.count <= 10 {
            masked = String(repeating: "*", count: min(value.count, 4))
        } else {
            masked = value.prefix(6) + "..."
        }
        print("[\(module)] \(message): \(masked)")
    }
}
