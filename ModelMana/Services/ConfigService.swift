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

    /// 读取配置，如果不存在则创建默认配置
    static func loadConfiguration() -> AppConfiguration {
        if FileManager.default.fileExists(atPath: configPath.path) {
            do {
                let data = try Data(contentsOf: configPath)
                return try JSONDecoder().decode(AppConfiguration.self, from: data)
            } catch {
                print("Failed to load config: \(error)")
            }
        }
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

    /// 创建默认配置
    private static func createDefaultConfiguration() -> AppConfiguration {
        let providers = Provider.allCases.map { provider in
            ProviderConfig(
                id: provider.id,
                name: provider.rawValue,
                baseUrl: provider.baseURL,
                apiKey: EnvService.read(provider.envKey) ?? ""
            )
        }
        return AppConfiguration(providers: providers, selectedProviderId: nil)
    }
}
