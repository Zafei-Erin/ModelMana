//
//  ClaudeLoginService.swift
//  ModelMana
//
//  Claude login/logout service
//

import Foundation
import AppKit

/// Claude login service
final class ClaudeLoginService {
    static let shared = ClaudeLoginService()

    private init() {}

    private func resolveClaudePath() throws -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        let paths = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/usr/bin/claude",
            "\(home)/.npm-global/bin/claude",
            "\(home)/.local/bin/claude",
        ]

        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        if let path = ShellPathLocator.which("claude") {
            return path
        }

        throw ClaudeLoginError.cliNotFound
    }

    private func openTerminal(withCommand: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "tell application \"Terminal\"\ndo script \"\(withCommand.replacingOccurrences(of: "\"", with: "\\\""))\"\nactivate\nend tell"
        ]

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                throw ClaudeLoginError.launchFailed("Failed to launch Terminal")
            }
        } catch {
            throw ClaudeLoginError.launchFailed("Failed to launch Terminal: \(error.localizedDescription)")
        }
    }

    func startLogin(
        method: ClaudeLoginMethod,
        onPhaseChange: @escaping @Sendable (ClaudeLoginPhase) -> Void
    ) async throws {
        onPhaseChange(.requesting)

        let claudePath = try resolveClaudePath()
        try openTerminal(withCommand: "\(claudePath) /login")

        try await Task.sleep(nanoseconds: 500_000_000)

        let timeout: TimeInterval = 120
        let startTime = Date()
        let isLoggedIn = method == .subscription ? ClaudeSessionService.isSubscriptionLoggedIn : ClaudeSessionService.isConsoleLoggedIn

        while Date().timeIntervalSince(startTime) < timeout {
            if isLoggedIn() {
                return
            }
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }

        throw ClaudeLoginError.timedOut
    }

    func startLogout() async throws {
        let claudePath = try resolveClaudePath()
        try openTerminal(withCommand: "\(claudePath) /logout")

        try await Task.sleep(nanoseconds: 2_000_000_000)

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 30 {
            if !ClaudeSessionService.isLoggedIn() {
                ClaudeSessionService.invalidateCache()
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        ClaudeSessionService.invalidateCache()
    }
}

/// Claude login errors
enum ClaudeLoginError: LocalizedError {
    case cliNotFound
    case timedOut
    case sessionNotCreated
    case launchFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .cliNotFound:
            return "Claude CLI not found. Please install it with: npm install -g @anthropic-ai/claude-code"
        case .timedOut:
            return "Login timed out. Please try again."
        case .sessionNotCreated:
            return "Session was not created. Please try again."
        case .launchFailed(let message):
            return "Failed to start login: \(message)"
        case .commandFailed(let output):
            return "Login failed. \(output.prefix(200))"
        }
    }
}

/// Claude session helper
struct ClaudeSessionService {
    private static let credentialsPath = ".claude/.credentials.json"
    private static let keychainService = "Claude Code"

    // Cache to avoid repeated keychain access
    private static var cachedCredentials: ClaudeOAuthCredentials?
    private static var cacheTimestamp: Date?
    private static let cacheValidityDuration: TimeInterval = 60 // 1 minute cache

    // Last fetched usage data
    static var lastUsage: ClaudeOAuthUsageResponse?

    /// Refresh usage data
    /// - Returns: Updated usage response
    /// - Throws: Error if credentials not found or API call fails
    static func refreshUsage() async throws -> ClaudeOAuthUsageResponse {
        let creds = try loadCredentials()
        let usage = try await ClaudeOAuthUsageFetcher.fetchUsage(accessToken: creds.accessToken)
        lastUsage = usage
        return usage
    }

    /// Get Claude credentials path (fallback file location)
    static func getCredentialsPath() -> URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return URL(fileURLWithPath: homeDir)
            .appendingPathComponent(credentialsPath)
    }

    /// Load OAuth credentials from Keychain or file
    /// - Returns: Claude OAuth credentials
    /// - Throws: ClaudeOAuthFetchError if credentials not found or expired
    static func loadCredentials() throws -> ClaudeOAuthCredentials {
        // Check cache first
        if let cached = cachedCredentials,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            return cached
        }

        // Try Keychain first (CLI writes there on macOS)
        var lastError: Error?
        if let keychainData = try? loadFromKeychain() {
            do {
                let creds = try parseCredentials(data: keychainData)
                cachedCredentials = creds
                cacheTimestamp = Date()
                Logger.log("Claude", "Credentials loaded from Keychain")
                return creds
            } catch {
                lastError = error
            }
        }

        // Fallback to file
        do {
            let fileData = try loadFromFile()
            let creds = try parseCredentials(data: fileData)
            cachedCredentials = creds
            cacheTimestamp = Date()
            Logger.log("Claude", "Credentials loaded from file")
            return creds
        } catch {
            if let lastError = lastError { throw lastError }
            throw error
        }
    }

    /// Check if user is logged in via Claude OAuth (Subscription/Console)
    /// Only checks Keychain and .credentials.json, not settings.json
    static func isLoggedIn() -> Bool {
        do {
            let creds = try loadCredentials()
            return !creds.isExpired
        } catch {
            return false
        }
    }

    /// Check if Subscription login is active (checks .credentials.json file)
    static func isSubscriptionLoggedIn() -> Bool {
        do {
            let data = try loadFromFile()
            let creds = try parseCredentials(data: data)
            return !creds.isExpired
        } catch {
            return false
        }
    }

    /// Check if Console login is active (checks Keychain for "Claude Code")
    static func isConsoleLoggedIn() -> Bool {
        do {
            let data = try loadFromKeychain()
            let creds = try parseCredentials(data: data)
            return !creds.isExpired
        } catch {
            return false
        }
    }

    /// Invalidate the credentials cache (call after login/logout)
    static func invalidateCache() {
        cachedCredentials = nil
        cacheTimestamp = nil
    }

    // MARK: - Private Helpers

    private static func loadFromKeychain() throws -> Data {
        #if os(macOS)
        // List of possible service names to try
        let serviceNames = [
            "Claude Code",
            "Claude Code-credentials",
            "claude-code",
            "com.anthropic.claude-code",
        ]

        // List of keychains to search
        let keychainDir = NSHomeDirectory() + "/Library/Keychains"
        let keychainPaths = [
            keychainDir + "/Claude Code.keychain-db",
            keychainDir + "/Claude Code.keychain",
            keychainDir + "/claude-code.keychain-db",
        ]

        // Try each combination of service name and keychain
        for service in serviceNames {
            for keychainPath in keychainPaths {
                if FileManager.default.fileExists(atPath: keychainPath) {
                    let query: [String: Any] = [
                        kSecClass as String: kSecClassGenericPassword,
                        kSecAttrService as String: service,
                        kSecMatchLimit as String: kSecMatchLimitOne,
                        kSecReturnData as String: true,
                        kSecMatchSearchList as String: [keychainPath]
                    ]

                    var result: AnyObject?
                    let status = SecItemCopyMatching(query as CFDictionary, &result)

                    if status == errSecSuccess, let data = result as? Data, !data.isEmpty {
                        return data
                    }
                }
            }
        }

        // Fallback to default keychain search
        for service in serviceNames {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecReturnData as String: true,
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            if status == errSecSuccess, let data = result as? Data, !data.isEmpty {
                return data
            }
        }

        throw ClaudeOAuthFetchError.credentialsNotFound
        #else
        throw ClaudeOAuthFetchError.credentialsNotFound
        #endif
    }

    private static func loadFromFile() throws -> Data {
        let path = getCredentialsPath()
        do {
            return try Data(contentsOf: path)
        } catch {
            if (error as NSError).code == NSFileReadNoSuchFileError {
                throw ClaudeOAuthFetchError.credentialsNotFound
            }
            throw ClaudeOAuthFetchError.readFailed(error.localizedDescription)
        }
    }

    private static func parseCredentials(data: Data) throws -> ClaudeOAuthCredentials {
        // First, try to parse as JSON with OAuth credentials
        if let jsonString = String(data: data, encoding: .utf8),
           jsonString.hasPrefix("{") {
            let decoder = JSONDecoder()
            guard let root = try? decoder.decode(Root.self, from: data) else {
                throw ClaudeOAuthFetchError.invalidResponse
            }
            guard let oauth = root.claudeAiOauth else {
                throw ClaudeOAuthFetchError.invalidResponse
            }
            let accessToken = (oauth.accessToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !accessToken.isEmpty else {
                throw ClaudeOAuthFetchError.invalidResponse
            }
            let expiresAt = oauth.expiresAt.map { millis in
                Date(timeIntervalSince1970: millis / 1000.0)
            }
            return ClaudeOAuthCredentials(
                accessToken: accessToken,
                refreshToken: oauth.refreshToken,
                expiresAt: expiresAt,
                scopes: oauth.scopes ?? [],
                rateLimitTier: oauth.rateLimitTier
            )
        }

        // Otherwise, treat as plain API key
        guard let apiKey = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty else {
            throw ClaudeOAuthFetchError.invalidResponse
        }
        // For API keys, we don't have refresh token, expiry, or scopes
        return ClaudeOAuthCredentials(
            accessToken: apiKey,
            refreshToken: nil,
            expiresAt: nil,
            scopes: [],
            rateLimitTier: nil
        )
    }

    private struct Root: Decodable {
        let claudeAiOauth: OAuthData?
    }

    private struct OAuthData: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let expiresAt: Double?
        let scopes: [String]?
        let rateLimitTier: String?
    }
}

// MARK: - ClaudeOAuthFetchError Extension

extension ClaudeOAuthFetchError {
    static func keychainError(_ status: Int) -> Self {
        .readFailed("Keychain error: \(status)")
    }
}
