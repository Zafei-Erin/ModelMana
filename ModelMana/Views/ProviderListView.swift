//
//  ProviderListView.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import SwiftUI

struct ProviderListView: View {
    @State private var appState = AppState.shared
    @State private var selectedProvider: Provider?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("ModelMana")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Provider List
            VStack(spacing: 0) {
                ForEach(Provider.allCases) { provider in
                    ProviderRowView(
                        provider: provider,
                        isSelected: selectedProvider == provider,
                        apiKey: appState.configuration.providers.first { $0.id == provider.id }?.apiKey
                    ) {
                        selectProvider(provider)
                    }
                }
            }

            Divider()

            // Messages
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button(action: { clearMessages() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
            } else if let success = successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(success)
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                    Button(action: { clearMessages() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
            }

            Divider()

            // Footer Buttons
            VStack(spacing: 0) {
                Button(action: {
                    openWindow(id: "settings")
                }) {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)

                Divider()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit")
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 240)
        .onAppear {
            selectedProvider = SettingsFileService.getCurrentProvider()
        }
    }

    private func selectProvider(_ provider: Provider) {
        guard let providerConfig = appState.configuration.providers.first(where: { $0.id == provider.id }),
              !providerConfig.apiKey.isEmpty else {
            errorMessage = "未找到 \(provider.rawValue) 的 API Key，请先在设置中配置"
            successMessage = nil
            return
        }

        do {
            try SettingsFileService.writeSettings(
                provider: provider,
                apiKey: providerConfig.apiKey
            )
            appState.configuration.selectedProviderId = provider.id
            selectedProvider = provider
            successMessage = "已切换到 \(provider.rawValue)"
            errorMessage = nil
        } catch {
            errorMessage = "切换失败: \(error.localizedDescription)"
            successMessage = nil
        }
    }

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}

struct ProviderRowView: View {
    let provider: Provider
    let isSelected: Bool
    let apiKey: String?
    let onTap: () -> Void

    // 遮盖 API key，只显示前缀和后4位
    private var maskedApiKey: String {
        guard let key = apiKey, !key.isEmpty else {
            return "未设置 - 点击设置配置"
        }
        if key.count <= 8 {
            return String(repeating: "•", count: key.count)
        }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)...\(suffix)"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)

                    Text(provider.rawValue)
                        .foregroundColor(.primary)

                    Spacer()

                    if apiKey != nil && !apiKey!.isEmpty {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // 显示遮盖后的 API key
                Text(maskedApiKey)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(apiKey != nil && !apiKey!.isEmpty ? .secondary : .red.opacity(0.7))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

#Preview {
    ProviderListView()
}
