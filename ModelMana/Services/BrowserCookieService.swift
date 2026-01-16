//
//  BrowserCookieService.swift
//  ModelMana
//
//  Generic browser cookie fetching service
//  Uses SweetCookieKit for cross-browser cookie reading
//

import Foundation
import WebKit
import SweetCookieKit

// MARK: - Cookie Fetch Error

enum CookieFetchError: LocalizedError {
    case noBrowserFound
    case cookieNotFound(String)
    case unsupportedBrowser(String)
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .noBrowserFound:
            return "No supported browser found"
        case .cookieNotFound(let name):
            return "Cookie '\(name)' not found"
        case .unsupportedBrowser(let browser):
            return "Browser '\(browser)' is not supported"
        case .fetchFailed(let reason):
            return "Failed to fetch cookies: \(reason)"
        }
    }
}

// MARK: - Browser Cookie Service

enum BrowserCookieService {

    /// Default browsers to try for cookie fetching
    public static let defaultBrowsers: [Browser] = [.safari, .chrome, .arc]

    /// Fetch cookies for a domain from browsers (with caching)
    /// - Parameters:
    ///   - domain: The domain to fetch cookies for (e.g., "platform.claude.com")
    ///   - cookieNames: Names of cookies to fetch
    ///   - browsers: List of browsers to try (in order)
    ///   - storeIdentifier: Unique identifier for the cache store
    ///   - requiredCookie: At least one of these cookies must exist to consider the browser valid
    /// - Returns: Dictionary of cookie name to value
    static func fetchCookies(
        for domain: String,
        cookieNames: [String],
        browsers: [Browser] = defaultBrowsers,
        storeIdentifier: String = "default",
        requiredCookie: String = "sessionKey"
    ) async throws -> [String: String] {
        // Try cache first
        let cached = try? await getCachedCookies(for: domain, cookieNames: cookieNames, storeIdentifier: storeIdentifier)
        if let cached = cached, !cached.isEmpty {
            // Check if cache has the required cookie
            if cached[requiredCookie] != nil {
                print("[BrowserCookieService] Using cached cookies")
                return cached
            }
        }

        // Try browsers in order, stop at first one that has the required cookie
        for browser in browsers {
            do {
                let cookies = try await fetchFromBrowser(browser: browser, domain: domain, cookieNames: cookieNames)

                // Check if this browser has the required cookie
                if cookies[requiredCookie] != nil {
                    print("[BrowserCookieService] Using cookies from \(browser.displayName)")
                    // Cache the results
                    await setCachedCookies(cookies, for: domain, storeIdentifier: storeIdentifier)
                    return cookies
                } else {
                    print("[BrowserCookieService] \(browser.displayName) missing required cookie '\(requiredCookie)'")
                }
            } catch {
                print("[BrowserCookieService] Failed to fetch from \(browser.displayName): \(error.localizedDescription)")
            }
        }

        throw CookieFetchError.noBrowserFound
    }

    /// Fetch cookies from a specific browser
    private static func fetchFromBrowser(
        browser: Browser,
        domain: String,
        cookieNames: [String]
    ) async throws -> [String: String] {
        let client = BrowserCookieClient()

        // Create query for the domain
        let query = BrowserCookieQuery(domains: [domain])

        // Fetch cookies from the browser (synchronous API, run on background thread)
        let storeRecords = try await Task {
            try client.records(matching: query, in: browser)
        }.value

        print("[BrowserCookieService] \(browser.displayName): Found \(storeRecords.count) cookie stores")

        // Collect all cookies from all stores
        var allCookies: [String: String] = [:]
        for storeRecord in storeRecords {
            print("[BrowserCookieService]   Store '\(storeRecord.label)' has \(storeRecord.records.count) cookies")
            for record in storeRecord.records {
                if allCookies[record.name] == nil {  // First occurrence wins
                    allCookies[record.name] = record.value
                }
            }
        }

        // Log ALL cookies found (for debugging)
        print("[BrowserCookieService]   ALL cookies: \(Array(allCookies.keys).sorted().joined(separator: ", "))")

        // Log what we found
        let foundCookies = cookieNames.filter { allCookies[$0] != nil }
        let missingCookies = cookieNames.filter { allCookies[$0] == nil }
        print("[BrowserCookieService]   Requested: \(cookieNames.joined(separator: ", "))")
        print("[BrowserCookieService]   Found: \(foundCookies.joined(separator: ", "))")
        if !missingCookies.isEmpty {
            print("[BrowserCookieService]   Missing: \(missingCookies.joined(separator: ", "))")
        }

        // Return all matching cookies (may be partial)
        var result: [String: String] = [:]
        for name in cookieNames {
            if let value = allCookies[name] {
                result[name] = value
            }
        }

        if result.isEmpty {
            throw CookieFetchError.cookieNotFound(cookieNames.joined(separator: ", "))
        }

        return result
    }

    /// Get cookies with caching (tries cache first, then browsers)
    /// - Parameters:
    ///   - domain: The domain to fetch cookies for
    ///   - cookieNames: Names of cookies to fetch
    ///   - storeIdentifier: Unique identifier for the cache store
    /// - Returns: Dictionary of cookie name to value
    static func getCachedCookies(
        for domain: String,
        cookieNames: [String],
        storeIdentifier: String
    ) async throws -> [String: String] {
        let cache = WebsiteDataStoreCache.shared(for: storeIdentifier)
        let allCookies = try await cache.getCookies(for: domain)

        // Filter to only requested cookies
        var result: [String: String] = [:]
        for name in cookieNames {
            if let value = allCookies[name] {
                result[name] = value
            }
        }

        return result
    }

    /// Store cookies in cache
    /// - Parameters:
    ///   - cookies: Dictionary of cookie name to value
    ///   - domain: Domain these cookies are for
    ///   - storeIdentifier: Unique identifier for the cache store
    static func setCachedCookies(
        _ cookies: [String: String],
        for domain: String,
        storeIdentifier: String
    ) async {
        let cache = WebsiteDataStoreCache.shared(for: storeIdentifier)
        await cache.setCookies(cookies, for: domain)
    }

    /// Clear cached cookies for a domain
    /// - Parameters:
    ///   - domain: Domain to clear cookies for
    ///   - storeIdentifier: Unique identifier for the cache store
    static func clearCachedCookies(
        for domain: String,
        storeIdentifier: String
    ) async {
        let cache = WebsiteDataStoreCache.shared(for: storeIdentifier)
        await cache.clearCookies(for: domain)
    }
}
