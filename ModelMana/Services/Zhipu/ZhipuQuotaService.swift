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
    /// - Returns: Result 包含 (percentage: Double, nextResetTime: TimeInterval) 或 Error
    static func fetchQuota(apiKey: String) async -> Result<(percentage: Double, nextResetTime: TimeInterval), Error> {
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

            // Debug: 打印完整的 limits 数组来查看有哪些类型
            Logger.log("Zhipu", "All limits: \(data)")

            // 找到 type == "TOKENS_LIMIT" 且 unit == 3 的项
            for limit in limits {
                if let type = limit["type"] as? String,
                   type == "TOKENS_LIMIT",
                   let unit = limit["unit"] as? Int,
                   unit == 3,
                   let percentage = limit["percentage"] as? Double {
                    let nextResetTime = (limit["nextResetTime"] as? TimeInterval)
                        ?? (Date().addingTimeInterval(5 * 3600).timeIntervalSince1970 * 1000)
                    return .success((percentage: percentage, nextResetTime: nextResetTime))
                }
            }

            return .failure(QuotaError.parseError("TOKENS_LIMIT data not found"))

        } catch {
            return .failure(error)
        }
    }

    /// 查询 API Key 的配额使用情况（带回调，用于非 async 上下文）
    /// - Parameters:
    ///   - apiKey: Zhipu API Key
    ///   - completion: 完成回调
    static func fetchQuota(apiKey: String, completion: @escaping (Result<(percentage: Double, nextResetTime: TimeInterval), Error>) -> Void) {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(QuotaError.parseError("Empty response")))
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                completion(.failure(QuotaError.httpError(httpResponse.statusCode)))
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let data = json["data"] as? [String: Any],
               let limits = data["limits"] as? [[String: Any]] {

                for limit in limits {
                    if let type = limit["type"] as? String,
                       type == "TOKENS_LIMIT",
                       let unit = limit["unit"] as? Int,
                       unit == 3,
                       let percentage = limit["percentage"] as? Double {
                        let nextResetTime = (limit["nextResetTime"] as? TimeInterval)
                            ?? (Date().addingTimeInterval(5 * 3600).timeIntervalSince1970 * 1000)
                        completion(.success((percentage: percentage, nextResetTime: nextResetTime)))
                        return
                    }
                }

                completion(.failure(QuotaError.parseError("TOKENS_LIMIT data not found")))
            } else {
                completion(.failure(QuotaError.parseError("JSON parse failed")))
            }
        }.resume()
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
