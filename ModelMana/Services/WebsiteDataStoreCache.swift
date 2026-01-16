//
//  WebsiteDataStoreCache.swift
//  ModelMana
//
//  Generic WKWebsiteDataStore cache for browser cookies
//

import Foundation
import WebKit

// MARK: - Website Data Store Cache

/// Actor-based cache using WKWebsiteDataStore for persistent cookie storage
actor WebsiteDataStoreCache {

    private static var caches: [String: WKWebsiteDataStore] = [:]
    private static let lock = NSLock()
    private let dataStore: WKWebsiteDataStore

    /// Get or create a shared data store instance for the given identifier
    /// - Parameter identifier: Unique identifier for this cache (e.g., bundle.id.service-name)
    /// - Returns: Shared cache instance
    static func shared(for identifier: String) -> WebsiteDataStoreCache {
        // Get or create data store on main thread
        let dataStore: WKWebsiteDataStore
        lock.lock()
        if let cached = caches[identifier] {
            dataStore = cached
        } else {
            dataStore = DispatchQueue.main.sync {
                WKWebsiteDataStore.default()
            }
            caches[identifier] = dataStore
        }
        lock.unlock()
        return WebsiteDataStoreCache(dataStore: dataStore)
    }

    private init(dataStore: WKWebsiteDataStore) {
        self.dataStore = dataStore
    }

    /// Get all cookies for a given domain
    /// - Parameter domain: The domain to get cookies for (e.g., "platform.claude.com")
    /// - Returns: Dictionary of cookie name to value
    func getCookies(for domain: String) async throws -> [String: String] {
        let cookieStore = dataStore.httpCookieStore
        let cookies = try await cookieStore.allCookies()

        return cookies
            .filter { $0.domain.contains(domain) || domain.contains($0.domain) }
            .reduce(into: [String: String]()) { result, cookie in
                result[cookie.name] = cookie.value
            }
    }

    /// Set cookies for a domain
    /// - Parameters:
    ///   - cookies: Dictionary of cookie name to value
    ///   - domain: The domain these cookies are for
    func setCookies(_ cookies: [String: String], for domain: String) async {
        let cookieStore = dataStore.httpCookieStore

        await MainActor.run {
            for (name, value) in cookies {
                if let cookie = HTTPCookie(
                    properties: [
                        .name: name,
                        .value: value,
                        .domain: domain,
                        .path: "/",
                        .secure: true
                    ]
                ) {
                    cookieStore.setCookie(cookie)
                }
            }
        }
    }

    /// Clear all cookies for a domain
    /// - Parameter domain: The domain to clear cookies for
    func clearCookies(for domain: String) async {
        let cookieStore = dataStore.httpCookieStore
        let allCookies = try? await cookieStore.allCookies()

        await MainActor.run {
            let cookiesToDelete = allCookies?
                .filter { $0.domain.contains(domain) || domain.contains($0.domain) } ?? []

            for cookie in cookiesToDelete {
                cookieStore.delete(cookie)
            }
        }
    }

    /// Clear all cookies in this data store
    func clearAllCookies() async {
        let cookieStore = dataStore.httpCookieStore
        let allCookies = try? await cookieStore.allCookies()

        await MainActor.run {
            for cookie in allCookies ?? [] {
                cookieStore.delete(cookie)
            }
        }
    }
}
