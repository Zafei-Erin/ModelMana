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

        print("[ZhipuQuota] 发送请求: \(baseURL)")
        print("[ZhipuQuota] Authorization: \(apiKey.prefix(10))...")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // 检查 HTTP 状态码
            if let httpResponse = response as? HTTPURLResponse {
                print("[ZhipuQuota] HTTP 状态码: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    // 打印错误响应
                    if let errorResponse = String(data: data, encoding: .utf8) {
                        print("[ZhipuQuota] 错误响应: \(errorResponse)")
                    }
                    return .failure(QuotaError.httpError(httpResponse.statusCode))
                }
            }

            // 打印原始响应
            if let responseString = String(data: data, encoding: .utf8) {
                print("[ZhipuQuota] 响应内容: \(responseString)")
            }

            // 解析 JSON
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let data = json["data"] as? [String: Any],
                  let limits = data["limits"] as? [[String: Any]] else {
                print("[ZhipuQuota] JSON 解析失败")
                return .failure(QuotaError.parseError("JSON 解析失败"))
            }

            print("[ZhipuQuota] limits 数量: \(limits.count)")

            // 找到 type == "TOKENS_LIMIT" 且 unit == 3 的项
            for limit in limits {
                if let type = limit["type"] as? String,
                   type == "TOKENS_LIMIT",
                   let unit = limit["unit"] as? Int,
                   unit == 3,
                   let percentage = limit["percentage"] as? Double,
                   let nextResetTime = limit["nextResetTime"] as? TimeInterval {
                    print("[ZhipuQuota] 成功获取配额: \(percentage)%")
                    return .success((percentage: percentage, nextResetTime: nextResetTime))
                }
            }

            print("[ZhipuQuota] 未找到 TOKENS_LIMIT (unit=3) 数据")
            return .failure(QuotaError.parseError("未找到 TOKENS_LIMIT 数据"))

        } catch {
            print("[ZhipuQuota] 请求错误: \(error)")
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

        let maskedKey = apiKey.prefix(10) + "..."
        print("[ZhipuQuota] 发送请求: \(baseURL), Authorization: \(maskedKey)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[ZhipuQuota] 网络错误: \(error)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                print("[ZhipuQuota] 响应数据为空")
                completion(.failure(QuotaError.parseError("响应数据为空")))
                return
            }

            // 检查 HTTP 状态码
            if let httpResponse = response as? HTTPURLResponse {
                print("[ZhipuQuota] HTTP 状态码: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    if let errorResponse = String(data: data, encoding: .utf8) {
                        print("[ZhipuQuota] 错误响应: \(errorResponse)")
                    }
                    completion(.failure(QuotaError.httpError(httpResponse.statusCode)))
                    return
                }
            }

            // 打印原始响应
            if let responseString = String(data: data, encoding: .utf8) {
                print("[ZhipuQuota] 响应内容: \(responseString)")
            }

            // 解析 JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let data = json["data"] as? [String: Any],
               let limits = data["limits"] as? [[String: Any]] {

                print("[ZhipuQuota] limits 数量: \(limits.count)")

                // 找到 type == "TOKENS_LIMIT" 且 unit == 3 的项
                for limit in limits {
                    if let type = limit["type"] as? String,
                       type == "TOKENS_LIMIT",
                       let unit = limit["unit"] as? Int,
                       unit == 3,
                       let percentage = limit["percentage"] as? Double,
                       let nextResetTime = limit["nextResetTime"] as? TimeInterval {
                        print("[ZhipuQuota] 成功获取配额: \(percentage)%")
                        completion(.success((percentage: percentage, nextResetTime: nextResetTime)))
                        return
                    }
                }

                print("[ZhipuQuota] 未找到 TOKENS_LIMIT (unit=3) 数据")
                completion(.failure(QuotaError.parseError("未找到 TOKENS_LIMIT 数据")))
            } else {
                print("[ZhipuQuota] JSON 解析失败")
                completion(.failure(QuotaError.parseError("JSON 解析失败")))
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
            return "HTTP 错误: \(code)"
        case .parseError(let message):
            return "解析错误: \(message)"
        }
    }
}
