//
//  ClaudeLoginService.swift
//  ModelMana
//
//  Claude login service using PTY
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
                // Check if actually logged in by verifying session cookie
                if ClaudeSessionService.isLoggedIn() {
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
    /// Get Claude session cookie path
    static func getSessionCookiePath() -> URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return URL(fileURLWithPath: homeDir)
            .appendingPathComponent(".claude")
            .appendingPathComponent("session_cookie")
    }

    /// Check if user is logged in
    static func isLoggedIn() -> Bool {
        let path = getSessionCookiePath()
        return FileManager.default.fileExists(atPath: path.path)
    }
}
