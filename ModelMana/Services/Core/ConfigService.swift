//
//  ConfigService.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import Foundation

struct ConfigService {
    private static let configDirName = ".modelmana"
    private static let configFileName = "config.json"

    private static var configDir: URL {
        let realHome = getRealHomeDirectory()
        return URL(fileURLWithPath: realHome).appendingPathComponent(configDirName)
    }

    private static var configPath: URL {
        configDir.appendingPathComponent(configFileName)
    }

    /// 读取配置
    static func loadConfiguration() -> AppConfiguration {
        if FileManager.default.fileExists(atPath: configPath.path) {
            do {
                let data = try Data(contentsOf: configPath)
                let config = try JSONDecoder().decode(AppConfiguration.self, from: data)
                let keyCounts = config.providers.map { "\($0.name): \($0.apiKeys.count) keys" }.joined(separator: ", ")
                Logger.log("Config", "Loaded \(config.providers.count) providers (\(keyCounts))")
                return config
            } catch {
                Logger.error("Config", error.localizedDescription)
            }
        }

        Logger.log("Config", "Creating default config")
        return createDefaultConfiguration()
    }

    /// 保存配置
    static func saveConfiguration(_ config: AppConfiguration) throws {
        if !FileManager.default.fileExists(atPath: configDir.path) {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configPath)
    }

    /// 创建默认配置（包含预置的 providers）
    private static func createDefaultConfiguration() -> AppConfiguration {
        let providers = [
            // Zhipu
            ProviderConfig(
                id: "zhipu",
                name: "Zhipu",
                baseUrl: "https://open.bigmodel.cn/api/anthropic",
                apiKeys: []
            ),
            // Claude
            ProviderConfig(
                id: "claude",
                name: "Claude",
                baseUrl: "https://api.anthropic.com",
                apiKeys: []
            ),
            // Minimax
            ProviderConfig(
                id: "minimax",
                name: "Minimax",
                baseUrl: "https://api.minimaxi.com/anthropic",
                apiKeys: []
            )
        ]

        return AppConfiguration(providers: providers, selectedProviderId: nil, selectedApiKeyId: nil)
    }
}
