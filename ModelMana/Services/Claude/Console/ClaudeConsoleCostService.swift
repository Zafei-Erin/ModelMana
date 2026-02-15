//
//  ClaudeConsoleCostService.swift
//  ModelMana
//
//  Claude Console API cost metrics service
//

import Foundation

// MARK: - Claude Console Cost Service

enum ClaudeConsoleCostService {

    private static let baseURL = "https://platform.claude.com"
    private static let metricsPath = "/api/claude_code/metrics_aggs/overview"

    /// Fetch metrics for the current month (1st to 1st of next month)
    /// - Returns: Metrics response
    static func fetchCurrentMonthMetrics() async throws -> ClaudeConsoleMetricsResponse {
        let calendar = Calendar.current
        let now = Date()

        // Get current year and month
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        // Start: 1st of current month, End: 1st of next month
        let startDateStr = String(format: "%04d-%02d-01", year, month)

        let nextMonth = month == 12 ? 1 : month + 1
        let nextYear = month == 12 ? year + 1 : year
        let endDateStr = String(format: "%04d-%02d-01", nextYear, nextMonth)

        return try await fetchMetrics(startDateStr: startDateStr, endDateStr: endDateStr)
    }

    /// Fetch metrics for a custom date range
    /// - Parameters:
    ///   - startDateStr: Start date string (YYYY-MM-DD)
    ///   - endDateStr: End date string (YYYY-MM-DD)
    /// - Returns: Metrics response
    static func fetchMetrics(
        startDateStr: String,
        endDateStr: String
    ) async throws -> ClaudeConsoleMetricsResponse {
        // Get cookies
        let cookies = try await ClaudeConsoleCookieClient.getCookies()

        // Build URL with query parameters
        guard let baseURL = URL(string: baseURL + metricsPath) else {
            throw CookieAPIError.invalidURL
        }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!

        // Build query items
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "start_date", value: startDateStr),
            URLQueryItem(name: "end_date", value: endDateStr),
            URLQueryItem(name: "granularity", value: "daily")
        ]

        // Add organization UUID if available
        if let orgId = cookies.organizationId {
            queryItems.append(URLQueryItem(name: "organization_uuid", value: orgId))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw CookieAPIError.invalidURL
        }

        // Build additional headers
        var additionalHeaders: [String: String] = [
            "anthropic-client-platform": "web_console",
            "anthropic-device-id": cookies.deviceId
        ]

        // Add anonymous ID if available
        if let anonId = cookies.anonymousId {
            additionalHeaders["anthropic-anonymous-id"] = anonId
        }

        // Use generic API client
        return try await CookieAuthenticatedAPIClient.fetch(
            url: url,
            cookies: cookies.asDictionary,
            additionalHeaders: additionalHeaders,
            timeout: 120,
            responseType: ClaudeConsoleMetricsResponse.self
        )
    }
}

// MARK: - Convenience Extensions

extension ClaudeConsoleMetricsResponse {
    /// Get the total cost as a Double
    var totalCost: Double? {
        return summary.parsedCost
    }

    /// Get formatted cost string
    var formattedCost: String {
        return summary.formattedCost
    }
}
