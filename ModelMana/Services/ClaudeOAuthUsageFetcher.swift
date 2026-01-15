//
//  ClaudeOAuthUsageFetcher.swift
//  ModelMana
//
//  Fetch usage from Anthropic OAuth API
//

import Foundation

// MARK: - OAuth Usage Response Models

struct ClaudeOAuthUsageResponse: Decodable, Sendable {
    let fiveHour: OAuthUsageWindow?
    let sevenDay: OAuthUsageWindow?
    let sevenDayOAuthApps: OAuthUsageWindow?
    let sevenDayOpus: OAuthUsageWindow?
    let sevenDaySonnet: OAuthUsageWindow?
    let extraUsage: OAuthExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOAuthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case extraUsage = "extra_usage"
    }
}

struct OAuthUsageWindow: Decodable, Sendable {
    let utilization: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct OAuthExtraUsage: Decodable, Sendable {
    let isEnabled: Bool?
    let monthlyLimit: Double?
    let usedCredits: Double?
    let utilization: Double?
    let currency: String?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
        case currency
    }
}

// MARK: - Errors

enum ClaudeOAuthFetchError: LocalizedError {
    case unauthorized
    case invalidResponse
    case serverError(Int, String?)
    case networkError(Error)
    case credentialsNotFound
    case credentialsExpired
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .invalidResponse:
            return "Invalid response from server."
        case let .serverError(code, body):
            if let body, !body.isEmpty {
                return "Server error: \(code) – \(body)"
            }
            return "Server error: \(code)"
        case let .networkError(error):
            return "Network error: \(error.localizedDescription)"
        case .credentialsNotFound:
            return "Not logged in. Please log in first."
        case .credentialsExpired:
            return "Session expired. Please log in again."
        case let .readFailed(message):
            return "Failed to read credentials: \(message)"
        }
    }
}

// MARK: - Fetcher

enum ClaudeOAuthUsageFetcher {
    private static let baseURL = "https://api.anthropic.com"
    private static let usagePath = "/api/oauth/usage"
    private static let betaHeader = "oauth-2025-04-20"

    /// Fetch usage from Anthropic OAuth API
    /// - Parameter accessToken: OAuth access token or API key
    /// - Returns: OAuth usage response with utilization data
    static func fetchUsage(accessToken: String) async throws -> ClaudeOAuthUsageResponse {
        // Detect if this is an API key (starts with sk-ant-) or OAuth token
        let isApiKey = accessToken.hasPrefix("sk-ant-")

        // For API keys, we need a different approach since /api/oauth/usage doesn't work
        if isApiKey {
            // API keys can't use the OAuth usage endpoint
            // Return a placeholder response or try a different method
            throw ClaudeOAuthFetchError.invalidResponse
        }

        guard let url = URL(string: baseURL + usagePath) else {
            throw ClaudeOAuthFetchError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue("ModelMana/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ClaudeOAuthFetchError.invalidResponse
            }
            switch http.statusCode {
            case 200:
                return try decodeUsageResponse(data)
            case 401:
                throw ClaudeOAuthFetchError.unauthorized
            default:
                let body = String(data: data, encoding: .utf8)
                throw ClaudeOAuthFetchError.serverError(http.statusCode, body)
            }
        } catch let error as ClaudeOAuthFetchError {
            throw error
        } catch {
            throw ClaudeOAuthFetchError.networkError(error)
        }
    }

    private static func decodeUsageResponse(_ data: Data) throws -> ClaudeOAuthUsageResponse {
        let decoder = JSONDecoder()
        return try decoder.decode(ClaudeOAuthUsageResponse.self, from: data)
    }

    /// Parse ISO8601 date string
    static func parseISO8601Date(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - Credentials

struct ClaudeOAuthCredentials: Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let scopes: [String]
    let rateLimitTier: String?

    var isExpired: Bool {
        // For API keys (expiresAt is nil), they don't expire
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }

    var expiresIn: TimeInterval? {
        guard let expiresAt else { return nil }
        return expiresAt.timeIntervalSinceNow
    }
}
