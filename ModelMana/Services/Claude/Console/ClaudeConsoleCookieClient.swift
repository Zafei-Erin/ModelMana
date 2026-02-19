//
//  ClaudeConsoleCookieClient.swift
//  ModelMana
//
//  Claude Console cookie management
//

import Foundation
import SweetCookieKit

// MARK: - Claude Console Cookies

struct ClaudeConsoleCookies: Sendable {
    let sessionKey: String        // sessionKey cookie (sk-ant-sid01-...)
    let deviceId: String          // anthropic-device-id cookie
    let anonymousId: String?      // ajs_anonymous_id cookie (optional)
    let organizationId: String?   // lastActiveOrg cookie (optional)

    /// Convert to dictionary for API client
    var asDictionary: [String: String] {
        var result: [String: String] = [
            "sessionKey": sessionKey,
            "anthropic-device-id": deviceId
        ]
        if let anonId = anonymousId {
            result["anthropic-anonymous-id"] = anonId
        }
        return result
    }
}

// MARK: - Cookie Fetch Error

enum ClaudeCookieError: LocalizedError {
    case sessionKeyNotFound
    case deviceIdNotFound
    case noBrowserFound

    var errorDescription: String? {
        switch self {
        case .sessionKeyNotFound:
            return "Session key cookie not found. Please log in to Claude Console in your browser."
        case .deviceIdNotFound:
            return "Device ID cookie not found."
        case .noBrowserFound:
            return "No browser found with required cookies."
        }
    }
}

// MARK: - Claude Console Cookie Client

enum ClaudeConsoleCookieClient {

    // Multiple domains where cookies might be stored
    private static let domains = [
        "platform.claude.com",
        ".claude.com",
        "claude.com",
        ".anthropic.com",
        "anthropic.com"
    ]

    private static let browsers: [Browser] = [.chrome, .safari, .arc]
    private static let storeId = "com.zafei.ModelMana.claude-console"

    // Cookie names we're looking for (actual browser cookie names)
    private static let cookieNames = [
        "sessionKey",
        "anthropic-device-id",
        "ajs_anonymous_id",
        "lastActiveOrg"
    ]

    /// Get Claude Console cookies (from cache or browser)
    /// - Returns: Claude Console cookies
    /// - Throws: ClaudeCookieError if required cookies are missing
    static func getCookies() async throws -> ClaudeConsoleCookies {
        // Try each browser - for each browser, query ALL domains
        for browser in browsers {
            var browserCookies: [String: String] = [:]
            let client = BrowserCookieClient()

            // Query all domains for this browser
            for domain in domains {
                do {
                    let query = BrowserCookieQuery(domains: [domain])
                    let storeRecords = try await Task {
                        try client.records(matching: query, in: browser)
                    }.value

                    // Collect cookies from this domain
                    for storeRecord in storeRecords {
                        for record in storeRecord.records {
                            if cookieNames.contains(record.name) && browserCookies[record.name] == nil {
                                browserCookies[record.name] = record.value
                            }
                        }
                    }
                } catch {
                    // Continue to next domain
                }
            }

            // Check if this browser has the required cookies
            let hasSessionKey = browserCookies["sessionKey"] != nil
            let hasDeviceId = browserCookies["anthropic-device-id"] != nil

            if hasSessionKey && hasDeviceId {
                Logger.log("Claude", "Using cookies from \(browser.displayName)")

                // Cache the results (only from the primary domain)
                await BrowserCookieService.setCachedCookies(
                    browserCookies,
                    for: domains[0],
                    storeIdentifier: storeId
                )

                return ClaudeConsoleCookies(
                    sessionKey: browserCookies["sessionKey"]!,
                    deviceId: browserCookies["anthropic-device-id"]!,
                    anonymousId: browserCookies["ajs_anonymous_id"],
                    organizationId: browserCookies["lastActiveOrg"]
                )
            }
        }

        throw ClaudeCookieError.noBrowserFound
    }

    /// Manually set cookies (for testing or manual input)
    /// - Parameters:
    ///   - sessionKey: Session token from browser
    ///   - deviceId: Device ID from browser
    ///   - anonymousId: Anonymous ID from browser (optional)
    ///   - organizationId: Organization UUID (optional)
    static func setCookies(
        sessionKey: String,
        deviceId: String,
        anonymousId: String? = nil,
        organizationId: String? = nil
    ) async {
        var cookies: [String: String] = [
            "sessionKey": sessionKey,
            "anthropic-device-id": deviceId
        ]
        if let anonId = anonymousId {
            cookies["ajs_anonymous_id"] = anonId
        }
        if let orgId = organizationId {
            cookies["lastActiveOrg"] = orgId
        }
        await BrowserCookieService.setCachedCookies(
            cookies,
            for: domains[0],
            storeIdentifier: storeId
        )
    }

    /// Clear stored cookies
    static func clearCookies() async {
        await BrowserCookieService.clearCachedCookies(
            for: domains[0],
            storeIdentifier: storeId
        )
    }

    /// Check if cookies are available
    static func hasCookies() async -> Bool {
        do {
            _ = try await getCookies()
            return true
        } catch {
            return false
        }
    }
}
