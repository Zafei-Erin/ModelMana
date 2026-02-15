//
//  ClaudeLoginService.swift
//  ModelMana
//
//  Claude login/logout service using PTY
//

import Foundation

/// Claude login service
final class ClaudeLoginService {
    static let shared = ClaudeLoginService()

    private init() {}

    /// Start Claude login process
    /// - Parameters:
    ///   - method: Login method (subscription or console)
    ///   - onPhaseChange: Callback for phase changes
    /// - Returns: Async throws - success or error
    func startLogin(
        method: ClaudeLoginMethod,
        onPhaseChange: @escaping @Sendable (ClaudeLoginPhase) -> Void
    ) async throws {
        onPhaseChange(.requesting)

        let runner = TTYCommandRunner()
        var options = TTYCommandRunner.Options(
            rows: 50,
            cols: 160,
            timeout: 120,
            extraArgs: ["/login"],
            initialDelay: 0.4,
            settleAfterStop: 0.35
        )

        // Stop when login succeeds
        options.stopOnSubstrings = [
            "Successfully logged in",
            "Login successful",
            "Logged in successfully",
            "already logged in"
        ]

        // Auto-select login method when prompted
        // The TUI shows a cursor ❯ on the selected option
        if method == .subscription {
            // Option 1 is already selected, just press Enter
            options.sendOnSubstrings = [
                "Select login method:": "\r"
            ]
        } else {
            // For console (option 2), press Down arrow first, then Enter when we see option 2 highlighted
            options.sendOnSubstrings = [
                "Select login method:": "\u{1B}[B",           // Down arrow (ESC[B) to move to option 2
                "Anthropic Console account": "\r"            // Press Enter when option 2 is shown
            ]
            // Add delay after sending Down arrow to let TUI update cursor position
            options.sendDelays = [
                "Select login method:": 0.15  // Wait 150ms for cursor to move
            ]
        }

        do {
            let result = try runner.run(
                binary: "claude",
                send: "",
                options: options,
                onURLDetected: {
                    onPhaseChange(.waitingBrowser)
                }
            )

            // Verify success by checking output
            let output = result.text
            let hasSuccess = options.stopOnSubstrings.contains { output.contains($0) }

            if hasSuccess {
                // Check if actually logged in by verifying credentials
                ClaudeSessionService.invalidateCache()

                if ClaudeSessionService.isLoggedIn() {
                    // Fetch and cache usage after successful login
                    do {
                        let creds = try ClaudeSessionService.loadCredentials()
                        let usage = try await ClaudeOAuthUsageFetcher.fetchUsage(accessToken: creds.accessToken)
                        ClaudeSessionService.lastUsage = usage
                    } catch {
                        // Login succeeded but usage fetch failed - still consider login successful
                    }
                    return  // Success
                } else {
                    throw ClaudeLoginError.sessionNotCreated
                }
            } else {
                throw ClaudeLoginError.commandFailed(output)
            }

        } catch TTYCommandRunner.Error.binaryNotFound {
            throw ClaudeLoginError.cliNotFound
        } catch TTYCommandRunner.Error.timedOut {
            throw ClaudeLoginError.timedOut
        } catch TTYCommandRunner.Error.launchFailed(let message) {
            throw ClaudeLoginError.launchFailed(message)
        }
    }

    /// Start Claude logout process
    /// Runs `claude /logout` to let Claude CLI clean up its own credentials
    /// - Returns: Async throws - success or error
    func startLogout() async throws {
        let runner = TTYCommandRunner()
        var options = TTYCommandRunner.Options(
            rows: 50,
            cols: 160,
            timeout: 30,
            extraArgs: ["/logout"],
            initialDelay: 0.4,
            settleAfterStop: 0.35
        )

        // Stop when logout succeeds
        options.stopOnSubstrings = [
            "Successfully logged out from your Anthropic account",
            "Logged out successfully",
            "Successfully logged out",
            "You have been logged out"
        ]

        do {
            let result = try runner.run(
                binary: "claude",
                send: "",
                options: options,
                onURLDetected: {}
            )

            // Verify success by checking output
            let output = result.text
            let hasSuccess = options.stopOnSubstrings.contains { output.contains($0) }

            if hasSuccess {
                Logger.success("Claude", "Logged out")
                ClaudeSessionService.invalidateCache()
            } else {
                // Even if we don't see the success message, logout might have worked
                if !ClaudeSessionService.isLoggedIn() {
                    Logger.success("Claude", "Logged out")
                }
            }
        } catch TTYCommandRunner.Error.binaryNotFound {
            throw ClaudeLoginError.cliNotFound
        } catch TTYCommandRunner.Error.timedOut {
            throw ClaudeLoginError.timedOut
        } catch TTYCommandRunner.Error.launchFailed(let message) {
            throw ClaudeLoginError.launchFailed(message)
        }
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
