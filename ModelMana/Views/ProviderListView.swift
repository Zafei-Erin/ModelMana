//
//  ProviderListView.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import SwiftUI

struct ProviderListView: View {
    @Environment(\.openWindow) private var openWindow

    // 动态计算当前 provider
    private var currentProviderConfig: ProviderConfig? {
        let config = AppState.shared.configuration
        // 优先使用配置中的 selectedProviderId
        if let selectedId = config.selectedProviderId {
            return config.providers.first { $0.id == selectedId }
        }
        // 降级：从文件读取
        if let baseUrl = getCurrentProviderBaseURL() {
            return config.providers.first { $0.baseUrl == baseUrl }
        }
        return nil
    }

    var body: some View {
        let config = AppState.shared.configuration
        return VStack(spacing: 0) {
            // Header
            Text("ModelMana")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            // Current Provider Section
            VStack(alignment: .leading, spacing: 0) {
                Text("Current Provider")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if let current = currentProviderConfig {
                    ProviderSection(
                        providerConfig: current,
                        selectedApiKeyId: config.selectedApiKeyId,
                        isCurrent: true,
                        onSelectApiKey: { apiKeyId in
                            selectApiKey(providerConfig: current, apiKeyId: apiKeyId)
                        }
                    )
                }
            }

            Divider()

            // Available Providers Section
            VStack(alignment: .leading, spacing: 0) {
                Text("Available Providers")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ForEach(config.providers) { provider in
                    if provider.id != currentProviderConfig?.id {
                        ProviderSection(
                            providerConfig: provider,
                            selectedApiKeyId: config.selectedApiKeyId,
                            isCurrent: false,
                            onSelectApiKey: { apiKeyId in
                                selectApiKey(providerConfig: provider, apiKeyId: apiKeyId)
                            }
                        )
                    }
                }
            }

            Divider()

            // Settings
            Button(action: {
                openWindow(id: "settings")
            }) {
                Text("Settings")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Quit
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(red: 0.16, green: 0.16, blue: 0.16))
    }

    private func getCurrentProviderBaseURL() -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/settings.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let env = json["env"] as? [String: Any],
              let baseURL = env["ANTHROPIC_BASE_URL"] as? String else {
            return nil
        }
        return baseURL
    }

    private func selectApiKey(providerConfig: ProviderConfig, apiKeyId: String) {
        guard let apiKeyConfig = providerConfig.apiKeys.first(where: { $0.id == apiKeyId }) else {
            return
        }

        do {
            try SettingsFileService.writeSettings(
                baseUrl: providerConfig.baseUrl,
                apiKey: apiKeyConfig.key
            )
            var newConfig = AppState.shared.configuration
            newConfig.selectedProviderId = providerConfig.id
            newConfig.selectedApiKeyId = apiKeyId
            AppState.shared.configuration = newConfig

            print("[ModelMana] Selected: \(providerConfig.name) / \(apiKeyConfig.name)")
        } catch {
            print("[ModelMana] ERROR: \(error.localizedDescription)")
        }
    }
}

// Provider Section (使用 Menu 子菜单)
struct ProviderSection: View {
    let providerConfig: ProviderConfig
    let selectedApiKeyId: String?
    let isCurrent: Bool
    let onSelectApiKey: (String) -> Void

    var body: some View {
        Menu {
            // API Keys 列表
            if !providerConfig.apiKeys.isEmpty {
                ForEach(providerConfig.apiKeys) { keyConfig in
                    Button {
                        onSelectApiKey(keyConfig.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: keyConfig.id == selectedApiKeyId ? "checkmark" : "circle")
                                .frame(width: 16)

                            Text(keyConfig.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: {
                    openSettings()
                }) {
                    Text("No API keys - Open Settings")
                }
            }
        } label: {
            // Provider Header Row (作为 Menu 的触发器)
            HStack(spacing: 12) {
                // Provider Icon
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)

                    if providerConfig.id == "zhipu" {
                        Image("zhipu")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    } else if providerConfig.id == "claude" {
                        Image("claude")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "server.rack")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                    }
                }

                // Provider Name and Key Count
                VStack(alignment: .leading, spacing: 2) {
                    Text(providerConfig.name)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)

                    if providerConfig.apiKeys.isEmpty {
                        Text("No API keys")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    } else if let selectedId = selectedApiKeyId,
                              let currentKey = providerConfig.apiKeys.first(where: { $0.id == selectedId }) {
                        Text(currentKey.name)
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    } else {
                        Text("\(providerConfig.apiKeys.count) key\(providerConfig.apiKeys.count > 1 ? "s" : "")")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // 当前 provider 指示器
                if isCurrent {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                }

                // 子菜单指示器
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openSettings() {
        NSApp.sendAction(#selector(NSApplication.orderFrontStandardAboutPanel(_:)), to: nil, from: nil)
    }
}

#Preview {
    ProviderListView()
        .preferredColorScheme(.dark)
}
