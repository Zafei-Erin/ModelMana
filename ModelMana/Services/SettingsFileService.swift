//
//  SettingsFileService.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import Foundation

// 获取真实的用户主目录
func getRealHomeDirectory() -> String {
    var pwd = passwd()
    var pwdbuf = [Int8](repeating: 0, count: 1024)
    var result: UnsafeMutablePointer<passwd>?
    let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: 1024)
    defer { buffer.deallocate() }

    let status = getpwuid_r(getuid(), &pwd, buffer, 1024, &result)

    if status == 0, let result = result {
        return String(cString: result.pointee.pw_dir)
    }

    // 降级：使用环境变量
    if let envHome = ProcessInfo.processInfo.environment["HOME"] {
        return envHome
    }

    return NSHomeDirectory()
}

struct SettingsFileService {
    private static let claudeDirName = ".claude"
    private static let settingsFileName = "settings.json"

    private static var settingsPath: URL {
        let realHome = getRealHomeDirectory()
        return URL(fileURLWithPath: realHome)
            .appendingPathComponent(claudeDirName)
            .appendingPathComponent(settingsFileName)
    }

    /// 写入 Claude settings.json
    static func writeSettings(provider: Provider, apiKey: String) throws {
        let path = settingsPath

        // 确保目录存在
        let directory = path.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        // 读取现有配置
        var existing: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: path.path) {
            let data = try Data(contentsOf: path)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                existing = json
            }
        }

        // 构建 env 部分
        existing["env"] = [
            "ANTHROPIC_AUTH_TOKEN": apiKey,
            "ANTHROPIC_BASE_URL": provider.baseURL,
            "API_TIMEOUT_MS": "3000000",
            "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1
        ]

        // 写入文件
        let newData = try JSONSerialization.data(withJSONObject: existing, options: .prettyPrinted)
        try newData.write(to: path)
    }

    /// 获取当前配置的 provider
    static func getCurrentProvider() -> Provider? {
        let path = settingsPath
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let env = json["env"] as? [String: Any],
              let baseURL = env["ANTHROPIC_BASE_URL"] as? String else {
            return nil
        }

        return Provider.allCases.first { $0.baseURL == baseURL }
    }
}
