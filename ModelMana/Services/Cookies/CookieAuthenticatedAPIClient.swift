//
//  CookieAuthenticatedAPIClient.swift
//  ModelMana
//
//  Generic API client that uses cookies for authentication
//

import Foundation

// MARK: - Errors

enum CookieAPIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(Int, String?)
    case decodingError(Error)
    case noCookies

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code, let message):
            if let msg = message {
                return "HTTP error \(code): \(msg)"
            }
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noCookies:
            return "No cookies available"
        }
    }
}

// MARK: - Cookie Authenticated API Client

struct CookieAuthenticatedAPIClient {

    /// Fetch data from API using cookies for authentication
    /// - Parameters:
    ///   - url: The URL to fetch from
    ///   - cookies: Dictionary of cookie name to value
    ///   - additionalHeaders: Additional HTTP headers
    ///   - timeout: Request timeout in seconds (default 30)
    ///   - responseType: The type to decode the response as
    /// - Returns: Decoded response of type T
    static func fetch<T: Decodable>(
        url: URL,
        cookies: [String: String],
        additionalHeaders: [String: String] = [:],
        timeout: TimeInterval = 30,
        responseType: T.Type
    ) async throws -> T {
        guard !cookies.isEmpty else {
            throw CookieAPIError.noCookies
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add additional headers
        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Build Cookie header
        let cookieString = cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        request.setValue(cookieString, forHTTPHeaderField: "Cookie")

        // Debug logging
        print("[CookieAuthenticatedAPIClient] === API REQUEST ===")
        print("[CookieAuthenticatedAPIClient] URL: \(url.absoluteString)")
        print("[CookieAuthenticatedAPIClient] Method: GET")
        print("[CookieAuthenticatedAPIClient] Timeout: \(timeout)s")
        print("[CookieAuthenticatedAPIClient] Cookie: \(cookieString)")
        print("[CookieAuthenticatedAPIClient] Headers: \(additionalHeaders)")
        print("[CookieAuthenticatedAPIClient] ========================")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CookieAPIError.networkError(URLError(.badServerResponse))
            }

            print("[CookieAuthenticatedAPIClient] Response status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                print("[CookieAuthenticatedAPIClient] Response body: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw CookieAPIError.httpError(401, "Unauthorized. Please check cookies.")
            case 403:
                print("[CookieAuthenticatedAPIClient] Response body: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw CookieAPIError.httpError(403, "Forbidden. Insufficient permissions.")
            default:
                let body = String(data: data, encoding: .utf8)
                print("[CookieAuthenticatedAPIClient] ERROR Response body: \(body ?? "nil")")
                throw CookieAPIError.httpError(httpResponse.statusCode, body)
            }

            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(T.self, from: data)
                print("[CookieAuthenticatedAPIClient] ✓ Decode successful")
                return result
            } catch {
                print("[CookieAuthenticatedAPIClient] ✗ Decode error: \(error)")
                print("[CookieAuthenticatedAPIClient] Response body: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw CookieAPIError.decodingError(error)
            }

        } catch let error as CookieAPIError {
            throw error
        } catch {
            print("[CookieAuthenticatedAPIClient] ✗ Network error: \(error)")
            throw CookieAPIError.networkError(error)
        }
    }
}
