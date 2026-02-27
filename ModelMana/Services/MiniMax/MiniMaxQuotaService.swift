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
        request.setValue("CodexBar", forHTTPHeaderField: "MM-API-Source")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    return .failure(QuotaError.httpError(httpResponse.statusCode))
                }
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let baseResp = json["baseResp"] as? [String: Any],
                  let statusCode = baseResp["status_code"] as? Int,
                  statusCode == 0 else {
                return .failure(QuotaError.parseError("API returned error"))
            }

            guard let modelRemains = json["modelRemains"] as? [[String: Any]],
                  let firstModel = modelRemains.first else {
                return .failure(QuotaError.parseError("No quota data available"))
            }

            guard let totalCount = firstModel["currentIntervalTotalCount"] as? Double,
                  let usageCount = firstModel["currentIntervalUsageCount"] as? Double,
                  let endTime = firstModel["endTime"] as? TimeInterval else {
                return .failure(QuotaError.parseError("Missing quota fields"))
            }

            // Calculate percentage: (used / total) * 100
            let percentage = totalCount > 0 ? (usageCount / totalCount) * 100 : 0

            let item = QuotaItem(
                title: "Session",
                status: .success(percentage: percentage, nextResetTime: endTime)
            )

            return .success([item])

        } catch {
            return .failure(error)
        }
    }
}
