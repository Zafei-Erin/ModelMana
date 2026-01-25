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
                "Yes, proceed": "\r",  // Auto-confirm folder trust prompt
                "Select login method:": "\r"
            ]
            print("[ClaudeLoginService] Subscription mode: will send Enter on 'Select login method:'")
        } else {
            // For console (option 2), press Down arrow first, then Enter when we see option 2 highlighted
            options.sendOnSubstrings = [
                "Yes, proceed": "\r",  // Auto-confirm folder trust prompt
                "Select login method:": "\u{1B}[B",           // Down arrow (ESC[B) to move to option 2
                "Anthropic Console account": "\r"            // Press Enter when option 2 is shown
            ]
            // Add delay after sending Down arrow to let TUI update cursor position
            options.sendDelays = [
                "Select login method:": 0.15  // Wait 150ms for cursor to move
            ]
            print("[ClaudeLoginService] Console mode: will send Down arrow then Enter with delay")
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

            print("[ClaudeLoginService] CLI output length: \(output.count)")
            print("[ClaudeLoginService] Found success substring: \(hasSuccess)")
            if !hasSuccess {
                print("[ClaudeLoginService] Output preview: \(output.prefix(500))")
            }

            if hasSuccess {
                // Check if actually logged in by verifying credentials
                ClaudeSessionService.invalidateCache()

                print("[ClaudeLoginService] Checking if logged in...")
                let loggedIn = ClaudeSessionService.isLoggedIn()
                print("[ClaudeLoginService] isLoggedIn result: \(loggedIn)")

                if ClaudeSessionService.isLoggedIn() {
                    // Fetch and cache usage after successful login
                    do {
                        let creds = try ClaudeSessionService.loadCredentials()
                        let usage = try await ClaudeOAuthUsageFetcher.fetchUsage(accessToken: creds.accessToken)
                        // Store usage in a shared location for UI to access
                        ClaudeSessionService.lastUsage = usage
                    } catch {
                        // Login succeeded but usage fetch failed - still consider login successful
                        print("[ClaudeLoginService] Usage fetch failed after login: \(error.localizedDescription)")
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
        print("[ClaudeLoginService] Starting logout via CLI")

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
                print("[ClaudeLoginService] Logout completed successfully")
                // Invalidate cache after logout
                ClaudeSessionService.invalidateCache()
            } else {
                // Even if we don't see the success message, logout might have worked
                // Check if we're now logged out
                if !ClaudeSessionService.isLoggedIn() {
                    print("[ClaudeLoginService] Logout verified (no longer logged in)")
                } else {
                    print("[ClaudeLoginService] Logout may not have completed, but continuing...")
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
            print("[ClaudeSessionService] Returning cached credentials")
            return cached
        }

        // Try Keychain first (CLI writes there on macOS)
        print("[ClaudeSessionService] Trying to load from Keychain...")
        var lastError: Error?
        if let keychainData = try? loadFromKeychain() {
            print("[ClaudeSessionService] Keychain data found, size: \(keychainData.count) bytes")
            print("[ClaudeSessionService] Raw data preview: \(String(data: keychainData.prefix(200), encoding: .utf8) ?? "not UTF8")")
            do {
                let creds = try parseCredentials(data: keychainData)
                cachedCredentials = creds
                cacheTimestamp = Date()
                print("[ClaudeSessionService] Credentials loaded from Keychain successfully")
                return creds
            } catch {
                print("[ClaudeSessionService] Failed to parse Keychain data: \(error)")
                lastError = error
            }
        } else {
            print("[ClaudeSessionService] No Keychain data found")
        }

        // Fallback to file
        print("[ClaudeSessionService] Trying to load from file: \(getCredentialsPath().path)")
        do {
            let fileData = try loadFromFile()
            print("[ClaudeSessionService] File data found, size: \(fileData.count) bytes")
            let creds = try parseCredentials(data: fileData)
            cachedCredentials = creds
            cacheTimestamp = Date()
            print("[ClaudeSessionService] Credentials loaded from file successfully")
            return creds
        } catch {
            print("[ClaudeSessionService] File load failed: \(error)")
            if let lastError = lastError { throw lastError }
            throw error
        }
    }

    /// Check if user is logged in via Claude OAuth (Subscription/Console)
    /// Only checks Keychain and .credentials.json, not settings.json
    static func isLoggedIn() -> Bool {
        do {
            let creds = try loadCredentials()
            print("[ClaudeSessionService] Loaded credentials, isExpired: \(creds.isExpired)")
            return !creds.isExpired
        } catch {
            print("[ClaudeSessionService] loadCredentials failed: \(error.localizedDescription)")
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
            "Claude Code",                // Actual service name
            "Claude Code-credentials",  // Current version
            "claude-code",               // Alternative
            "com.anthropic.claude-code", // Bundle ID style
        ]

        // List of keychains to search
        let keychainDir = NSHomeDirectory() + "/Library/Keychains"
        let keychainPaths = [
            keychainDir + "/Claude Code.keychain-db",
            keychainDir + "/Claude Code.keychain",
            keychainDir + "/claude-code.keychain-db",
        ]

        print("[ClaudeSessionService] Keychain dir: \(keychainDir)")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: keychainDir) {
            print("[ClaudeSessionService] Keychain files: \(files.filter { $0.contains("Claude") || $0.contains("claude") })")
        }

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
                        print("[ClaudeSessionService] Found in keychain: \(keychainPath) with service: \(service)")
                        return data
                    }
                }
            }
        }

        // Fallback to default keychain search (searches all keychains) with different service names
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
                print("[ClaudeSessionService] Found in default search with service: \(service)")
                return data
            }
        }

        print("[ClaudeSessionService] No credentials found in any keychain")
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
        print("[ClaudeSessionService] Parsed as plain API key")
        // For API keys, we don't have refresh token, expiry, or scopes
        return ClaudeOAuthCredentials(
            accessToken: apiKey,
            refreshToken: nil,
            expiresAt: nil,  // API keys don't expire
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
