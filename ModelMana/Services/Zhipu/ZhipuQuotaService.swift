//
//  ZhipuQuotaService.swift
//  ModelMana
//
//  Zhipu API 配额查询服务
//

import Foundation

struct ZhipuQuotaService {
    private static let baseURL = "https://open.bigmodel.cn/api/monitor/usage/quota/limit"

    /// 查询 API Key 的配额使用情况
    /// - Parameter apiKey: Zhipu API Key
    /// - Returns: Result containing an array of QuotaItems (session + MCP) or Error
    static func fetchQuota(apiKey: String) async -> Result<[QuotaItem], Error> {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    return .failure(QuotaError.httpError(httpResponse.statusCode))
                }
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let data = json["data"] as? [String: Any],
                  let limits = data["limits"] as? [[String: Any]] else {
                return .failure(QuotaError.parseError("JSON parse failed"))
            }

            var items: [QuotaItem] = []

            // Parse TOKENS_LIMIT (unit=3) → Session (5h)
            if let sessionLimit = limits.first(where: { ($0["type"] as? String) == "TOKENS_LIMIT" && ($0["unit"] as? Int) == 3 }),
               let percentage = sessionLimit["percentage"] as? Double {
                let nextResetTime = (sessionLimit["nextResetTime"] as? TimeInterval)
                    ?? (Date().addingTimeInterval(5 * 3600).timeIntervalSince1970 * 1000)
                items.append(QuotaItem(title: "Session (5h)", status: .success(percentage: percentage, nextResetTime: nextResetTime)))
            } else {
                items.append(QuotaItem(title: "Session (5h)", status: .error("Data not found")))
            }

            // Parse TIME_LIMIT (unit=5) → MCP
            if let mcpLimit = limits.first(where: { ($0["type"] as? String) == "TIME_LIMIT" && ($0["unit"] as? Int) == 5 }),
               let percentage = mcpLimit["percentage"] as? Double {
                let nextResetTime = (mcpLimit["nextResetTime"] as? TimeInterval)
                    ?? (Date().addingTimeInterval(5 * 3600).timeIntervalSince1970 * 1000)
                items.append(QuotaItem(title: "MCP", status: .success(percentage: percentage, nextResetTime: nextResetTime)))
            } else {
                items.append(QuotaItem(title: "MCP", status: .error("Data not found")))
            }

            return .success(items)

        } catch {
            return .failure(error)
        }
    }
}

enum QuotaError: LocalizedError {
    case httpError(Int)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .parseError(let message):
            return message
        }
    }
}
