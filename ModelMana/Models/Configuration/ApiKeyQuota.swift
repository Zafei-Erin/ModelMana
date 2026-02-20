//
//  ApiKeyQuota.swift
//  ModelMana
//
//  Quota data models for API key usage tracking
//

import Foundation

/// A single quota measurement (e.g. session tokens, MCP time)
struct QuotaItem {
    enum Status {
        case success(percentage: Double, nextResetTime: TimeInterval)
        case error(String)
    }

    let title: String
    let status: Status

    /// Formatted reset time display
    var resetTimeText: String? {
        guard case .success(_, let nextResetTime) = status else { return nil }
        let interval = Date(timeIntervalSince1970: nextResetTime / 1000).timeIntervalSinceNow

        if interval <= 0 {
            return "Resets soon"
        }

        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if days > 0 {
            var parts = ["\(days)d"]
            if hours > 0 {
                parts.append("\(hours)h")
            }
            return "Resets in " + parts.joined(separator: " ")
        } else if hours > 0 {
            return "Resets in \(hours)h"
        } else {
            return "Resets in \(minutes)m"
        }
    }

    /// Get percentage if available
    var percentage: Double? {
        if case .success(let percentage, _) = status {
            return percentage
        }
        return nil
    }
}

/// Aggregated quota state for an API key
enum QuotaState {
    case loading
    case loaded([QuotaItem])
}
