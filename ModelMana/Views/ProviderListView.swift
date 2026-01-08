//
//  ProviderListView.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import SwiftUI

struct ProviderListView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var showingApiKeyPopover: Bool = false
    @State private var selectedProviderForKeys: ProviderConfig?

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
            HStack {
                Text("ModelMana")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    openWindow(id: "settings")
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))

                }
                .buttonStyle(.plain)

            }

            Divider().padding(.vertical, 6)

            // Current Provider Section
            VStack(alignment: .leading, spacing: 0) {
                Text("Current Provider")
                    .font(.system(size: 12))
                    .padding(.bottom, 8)

                if let current = currentProviderConfig {
                    ActiveKeySection(
                        providerId: current.id,
                        providerName: current.name,
                        apiKeyName: current.apiKeys.first(where: { $0.id == config.selectedApiKeyId })?.name ?? "Default"
                    ).padding(.horizontal, 2)
                }
            }

            Divider().padding(.vertical, 6)

            // Available Providers Section
            VStack(alignment: .leading, spacing: 0) {
                Text("Available Providers")
                    .font(.system(size: 12))
                    .padding(.bottom, 8)

                VStack(spacing: 6) {
                    ForEach(config.providers) { provider in
                        ProviderButton(providerConfig: provider)
                            .onTapGesture {
                                selectedProviderForKeys = provider
                                showingApiKeyPopover = true
                            }
                            .popover(isPresented: $showingApiKeyPopover) {
                                if let provider = selectedProviderForKeys {
                                    ApiKeySelectionPopover(
                                        provider: provider,
                                        selectedApiKeyId: config.selectedApiKeyId,
                                        onSelectApiKey: { apiKeyId in
                                            selectApiKey(providerConfig: provider, apiKeyId: apiKeyId)
                                            showingApiKeyPopover = false
                                        }
                                    )
                                }
                            }
                    }
                }
            }

            Divider().padding(.vertical, 6)

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
        }
        .padding(10)
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

struct ActiveKeySection: View {
    let providerId: String
    let providerName: String
    let apiKeyName: String

    var body: some View {
        HStack(spacing: 12) {
            ProviderIcon(providerId: providerId, size: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(providerName) - \(apiKeyName)")
                    .font(.system(size: 14))
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    ProgressView(value: 0.7, total: 1.0)
                        .progressViewStyle(.linear)
                    Text("70%")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProviderIcon: View {
    let providerId: String
    let size: CGFloat

    var body: some View {
        if providerId == "zhipu" {
            Image("zhipu")
                .renderingMode(.template)
                .resizable()
                .frame(width: size, height: size)
        } else if providerId == "claude" {
            Image("claude")
                .renderingMode(.template)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "server.rack")
                .font(.system(size: size))
                .foregroundStyle(.secondary)
        }
    }
}

// Provider Button (点击后弹出 Popover 选择 API Key)
struct ProviderButton: View {
    let providerConfig: ProviderConfig

    var body: some View {
        HStack(spacing: 12) {
            // Provider Icon
            ProviderIcon(providerId: providerConfig.id, size: 12)
            Text(providerConfig.name)
                .font(.system(size: 12))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// API Key Selection Popover
struct ApiKeySelectionPopover: View {
    let provider: ProviderConfig
    let selectedApiKeyId: String?
    let onSelectApiKey: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(provider.name) Keys")
                .font(.system(size: 12))
                .padding(.bottom, 8)

            if provider.apiKeys.isEmpty {
                Text("No API keys")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(provider.apiKeys) { key in
                    Button {
                        onSelectApiKey(key.id)
                    } label: {
                        HStack {
                            Image(systemName: key.id == selectedApiKeyId ? "checkmark" : "circle")
                                .frame(width: 16)
                            Text(key.name)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 250)
        .padding(5)
    }
}

#Preview {
    ProviderListView()
        .preferredColorScheme(.dark)
}
