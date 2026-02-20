//
//  ApiKeyQuota.swift
//  ModelMana
//
//  Created by refactoring from ProviderConfig.swift
//

import Foundation

/// API Key quota information
struct ApiKeyQuota {
    enum Status {
        case loading
        case success(percentage: Double, nextResetTime: TimeInterval)
        case error(String)
    }

    var status: Status
    var lastUpdated: Date
    var title: String?

    init(status: Status, lastUpdated: Date = Date(), title: String? = nil) {
        self.status = status
        self.lastUpdated = lastUpdated
        self.title = title
    }

    /// Formatted reset time display
    var resetTimeText: String? {
        guard case .success(_, let nextResetTime) = status else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        let time = formatter.string(from: Date(), to: Date(timeIntervalSince1970: nextResetTime / 1000)) ?? ""
        return "resets in " + time
    }

    /// Get percentage if available
    var percentage: Double? {
        if case .success(let percentage, _) = status {
            return percentage
        }
        return nil
    }
}
