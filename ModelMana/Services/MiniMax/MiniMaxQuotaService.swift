//
//  MiniMaxQuotaService.swift
//  ModelMana
//
//  MiniMax API 配额查询服务
//

import Foundation

struct MiniMaxQuotaService {
    private static let baseURL = "https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains"

    /// 查询 API Key 的配额使用情况
    /// - Parameter apiKey: MiniMax API Key
    /// - Returns: Result containing an array of QuotaItems or Error
    static func fetchQuota(apiKey: String) async -> Result<[QuotaItem], Error> {
        guard let url = URL(string: baseURL) else {
            return .failure(QuotaError.parseError("Invalid URL"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("ModelMana", forHTTPHeaderField: "MM-API-Source")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    return .failure(QuotaError.httpError(httpResponse.statusCode))
                }
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                // Log raw response for debugging
                if let rawString = String(data: data, encoding: .utf8) {
                    print("[MiniMax] Raw response: \(rawString)")
                }
                return .failure(QuotaError.parseError("Failed to parse JSON"))
            }

            // Check if base_resp exists and get status_code
            guard let baseResp = json["base_resp"] as? [String: Any] else {
                print("[MiniMax] Missing base_resp in response: \(json)")
                return .failure(QuotaError.parseError("Missing base_resp"))
            }

            guard let statusCode = baseResp["status_code"] as? Int,
                  statusCode == 0 else {
                // Log full response for debugging
                print("[MiniMax] API response: \(json)")
                let errorMsg = baseResp["status_msg"] as? String ?? "Unknown error"
                let code = baseResp["status_code"] as? Int ?? -1
                return .failure(QuotaError.parseError("API error \(code): \(errorMsg)"))
            }

            guard let modelRemains = json["model_remains"] as? [[String: Any]],
                  !modelRemains.isEmpty else {
                return .failure(QuotaError.parseError("No quota data available"))
            }

            var items: [QuotaItem] = []

            for model in modelRemains {
                guard let totalCount = model["current_interval_total_count"] as? Double,
                      let usageCount = model["current_interval_usage_count"] as? Double,
                      let endTime = model["end_time"] as? TimeInterval,
                      let modelName = model["model_name"] as? String else {
                    continue
                }

                // Calculate percentage: (used / total) * 100
                let percentage = totalCount > 0 ? (usageCount / totalCount) * 100 : 0

                // Use model name as title (e.g., "M2", "M2.1", "M2.5")
                let title = modelName.replacingOccurrences(of: "MiniMax-", with: "")

                items.append(QuotaItem(
                    title: title,
                    status: .success(percentage: percentage, nextResetTime: endTime)
                ))
            }

            // If no items were successfully parsed, return error
            if items.isEmpty {
                return .failure(QuotaError.parseError("Failed to parse any model data"))
            }

            return .success(items)

        } catch {
            return .failure(error)
        }
    }
}
