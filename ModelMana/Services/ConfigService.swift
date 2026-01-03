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
        print("[ConfigService] loadConfiguration, path: \(configPath.path)")

        if FileManager.default.fileExists(atPath: configPath.path) {
            do {
                let data = try Data(contentsOf: configPath)
                let config = try JSONDecoder().decode(AppConfiguration.self, from: data)
                print("[ConfigService] Loaded \(config.providers.count) providers")
                for p in config.providers {
                    print("[ConfigService]   - \(p.name): id=\(p.id), \(p.apiKeys.count) keys")
                }
                return config
            } catch {
                print("[ConfigService] ERROR: \(error)")
            }
        }

        print("[ConfigService] Creating default config")
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
        print("[ConfigService] Config saved")
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
            )
        ]

        return AppConfiguration(providers: providers, selectedProviderId: nil, selectedApiKeyId: nil)
    }
}
