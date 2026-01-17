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

    private static var claudeJsonPath: URL {
        let realHome = getRealHomeDirectory()
        return URL(fileURLWithPath: realHome).appendingPathComponent(".claude.json")
    }

    /// 写入 Claude settings.json
    static func writeSettings(baseUrl: String, apiKey: String) throws {
        let path = settingsPath
        print("[SettingsFileService] writeSettings called")
        print("[SettingsFileService] Target path: \(path.path)")

        // 确保目录存在
        let directory = path.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            print("[SettingsFileService] Creating directory: \(directory.path)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        // 读取现有配置
        var existing: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: path.path) {
            print("[SettingsFileService] Reading existing settings file")
            let data = try Data(contentsOf: path)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                existing = json
                print("[SettingsFileService] Existing settings loaded: \(existing.keys)")
            }
        }

        // 构建 env 部分
        existing["env"] = [
            "ANTHROPIC_AUTH_TOKEN": apiKey,
            "ANTHROPIC_BASE_URL": baseUrl,
            "API_TIMEOUT_MS": "3000000",
            "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1
        ]

        print("[SettingsFileService] Writing env: baseURL=\(baseUrl), apiKey=\(apiKey.prefix(10))...")

        // 写入文件
        let newData = try JSONSerialization.data(withJSONObject: existing, options: .prettyPrinted)
        try newData.write(to: path)
        print("[SettingsFileService] Settings written successfully")

        // 配置 claude.json
        try configureClaudeJson()
    }

    /// Write Claude settings for keychain-based auth (Subscription/Console)
    /// This removes auth tokens from env to allow Claude CLI to use Keychain credentials
    static func writeKeychainAuthSettings() throws {
        let path = settingsPath
        print("[SettingsFileService] writeKeychainAuthSettings called")

        // Ensure directory exists
        let directory = path.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        // Read existing config
        var existing: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: path.path) {
            let data = try Data(contentsOf: path)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                existing = json
            }
        }

        // Get or create env dict, REMOVE auth keys (don't set to empty)
        // When keys are absent, Claude CLI falls back to keychain
        var env = existing["env"] as? [String: Any] ?? [:]
        env.removeValue(forKey: "ANTHROPIC_AUTH_TOKEN")
        env.removeValue(forKey: "ANTHROPIC_BASE_URL")
        env["API_TIMEOUT_MS"] = "3000000"
        env["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] = 1
        existing["env"] = env

        // Write file
        let newData = try JSONSerialization.data(withJSONObject: existing, options: .prettyPrinted)
        try newData.write(to: path)
        print("[SettingsFileService] Keychain auth settings written")

        // Configure claude.json
        try configureClaudeJson()
    }

    /// 配置 ~/.claude.json，跳过 onboarding
    static func configureClaudeJson() throws {
        let path = claudeJsonPath
        print("[SettingsFileService] configureClaudeJson called, path: \(path.path)")

        // 读取现有配置
        var existing: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: path.path),
           let data = try? Data(contentsOf: path),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            existing = json
        }

        // 设置 hasCompletedOnboarding
        existing["hasCompletedOnboarding"] = true

        // 写入文件
        let newData = try JSONSerialization.data(withJSONObject: existing, options: .prettyPrinted)
        try newData.write(to: path)
        print("[SettingsFileService] Claude JSON configured successfully")
    }

    /// 获取当前配置的 baseURL
    static func getCurrentBaseUrl() -> String? {
        let path = settingsPath
        print("[SettingsFileService] getCurrentBaseUrl called, path: \(path.path)")

        guard FileManager.default.fileExists(atPath: path.path) else {
            print("[SettingsFileService] Settings file does not exist")
            return nil
        }

        guard let data = try? Data(contentsOf: path) else {
            print("[SettingsFileService] Failed to read settings file")
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[SettingsFileService] Failed to parse JSON")
            return nil
        }

        guard let env = json["env"] as? [String: Any] else {
            print("[SettingsFileService] No 'env' key in settings")
            return nil
        }

        guard let baseURL = env["ANTHROPIC_BASE_URL"] as? String else {
            print("[SettingsFileService] No 'ANTHROPIC_BASE_URL' in env")
            return nil
        }

        print("[SettingsFileService] Current baseURL: \(baseURL)")
        return baseURL
    }

    /// Delete Claude Code keychain entry
    /// Called when switching away from Claude subscription/console login
    /// Uses `claude /logout` to let Claude CLI clean up its own credentials
    static func deleteClaudeKeychainEntry() {
        print("[SettingsFileService] deleteClaudeKeychainEntry called - using claude /logout")

        // Run logout asynchronously
        Task {
            do {
                try await ClaudeLoginService.shared.startLogout()
                print("[SettingsFileService] Claude logout completed successfully")
            } catch {
                print("[SettingsFileService] Claude logout failed: \(error.localizedDescription)")
                // Logout failure is not critical - settings.json will be updated anyway
            }
        }
    }
}
