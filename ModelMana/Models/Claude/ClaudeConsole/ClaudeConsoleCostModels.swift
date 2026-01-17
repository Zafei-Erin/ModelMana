//
//  ClaudeConsoleCostModels.swift
//  ModelMana
//
//  Claude Console API cost tracking models
//

import Foundation

// MARK: - Metrics Response

struct ClaudeConsoleMetricsResponse: Decodable, Sendable {
    let organizationId: String
    let period: Period
    let summary: Summary

    enum CodingKeys: String, CodingKey {
        case organizationId = "organization_id"
        case period
        case summary
    }
}

// MARK: - Period

struct Period: Decodable, Sendable {
    let startDate: String
    let endDate: String
    let granularity: String

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case granularity
    }
}

// MARK: - Summary

struct Summary: Decodable, Sendable {
    let totalLinesAccepted: Int
    let toolAcceptRate: Double
    let commitsCreated: Int
    let pullRequestsCreated: Int
    let activeUsers: Int
    let totalSessions: Int
    let totalCostUsd: String
    let prsWithCc: Int
    let linesOfCodeWithCc: Int
    let prsWithCcPercentage: Double

    enum CodingKeys: String, CodingKey {
        case totalLinesAccepted = "total_lines_accepted"
        case toolAcceptRate = "tool_accept_rate"
        case commitsCreated = "commits_created"
        case pullRequestsCreated = "pull_requests_created"
        case activeUsers = "active_users"
        case totalSessions = "total_sessions"
        case totalCostUsd = "total_cost_usd"
        case prsWithCc = "prs_with_cc"
        case linesOfCodeWithCc = "lines_of_code_with_cc"
        case prsWithCcPercentage = "prs_with_cc_percentage"
    }

    /// Parse totalCostUsd string to Double
    var parsedCost: Double? {
        return Double(totalCostUsd)
    }

    /// Formatted cost string (e.g., "$1.50")
    var formattedCost: String {
        guard let cost = parsedCost else { return "$0.00" }
        return String(format: "$%.2f", cost)
    }
}
