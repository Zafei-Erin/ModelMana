//
//  ProviderListView.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import AppKit
import SwiftUI

struct ButtonFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct ProviderListView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var dropdownProvider: ProviderConfig?
    @State private var dropdownWindow: NSPanel?
    @State private var providerButtonFrames: [String: CGRect] = [:]
    @State private var eventMonitor: Any?

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
                        apiKeyName: current.apiKeys.first(where: {
                            $0.id == config.selectedApiKeyId
                        })?.name ?? "Default"
                    ).padding(.horizontal, 2)
                }
            }

            Divider().padding(.vertical, 6)

            // Available Providers Section
            VStack(alignment: .leading, spacing: 0) {
                Text("Available Providers")
                    .font(.system(size: 12))
                    .padding(.bottom, 8)

                // Provider 列表
                VStack(spacing: 0) {
                    ForEach(Array(config.providers.enumerated()), id: \.element.id) {
                        index, provider in
                        ProviderButton(
                            providerConfig: provider,
                            onTap: {
                                toggleDropdown(for: provider)
                            }
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ButtonFrameKey.self,
                                    value: [provider.id: geo.frame(in: .global)]
                                )
                            }
                        )
                        .padding(.bottom, index < config.providers.count - 1 ? 6 : 0)
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
        .frame(width: 230)
        .onPreferenceChange(ButtonFrameKey.self) { frames in
            providerButtonFrames = frames
        }
        .onDisappear {
            hideDropdown()
        }
    }

    private func getCurrentProviderBaseURL() -> String? {
        guard
            let data = try? Data(
                contentsOf: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(
                    ".claude/settings.json")),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let env = json["env"] as? [String: Any],
            let baseURL = env["ANTHROPIC_BASE_URL"] as? String
        else {
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

    private func toggleDropdown(for provider: ProviderConfig) {
        if dropdownProvider?.id == provider.id {
            hideDropdown()
        } else {
            showDropdown(for: provider)
        }
    }

    private func showDropdown(for provider: ProviderConfig) {
        hideDropdown()

        dropdownProvider = provider

        let config = AppState.shared.configuration

        // Create NSPanel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .popUpMenu
        panel.hasShadow = false

        let contentView = NSHostingView(
            rootView: ApiKeyDropdownPanel(
                provider: provider,
                selectedApiKeyId: config.selectedApiKeyId,
                onSelectApiKey: { apiKeyId in
                    selectApiKey(providerConfig: provider, apiKeyId: apiKeyId)
                }
            ))
        panel.contentView = contentView

        // Position window
        if let buttonFrame = providerButtonFrames[provider.id],
            let window = NSApp.keyWindow
        {
            // Convert window coordinates to screen coordinates
            let windowOrigin = window.convertPoint(
                toScreen: NSPoint(x: buttonFrame.minX, y: window.frame.height - buttonFrame.maxY))
            let x = windowOrigin.x + 230 - 10
            let y = windowOrigin.y - 168
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Click outside to close
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let window = dropdownWindow else { return event }
            // Check if click is inside the panel
            if window.frame.contains(NSEvent.mouseLocation) {
                // Click is inside panel, don't close
                return event
            }
            // Click is outside, close the dropdown
            hideDropdown()
            return event
        }

        panel.orderFront(nil)
        dropdownWindow = panel
    }

    private func hideDropdown() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        dropdownProvider = nil
        dropdownWindow?.close()
        dropdownWindow = nil
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
        }
    }
}

// Provider 按钮
struct ProviderButton: View {
    let providerConfig: ProviderConfig
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ProviderIcon(providerId: providerConfig.id, size: 12)
                Text(providerConfig.name)
                    .font(.system(size: 12))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

// API Key 下拉面板
struct ApiKeyDropdownPanel: View {
    let provider: ProviderConfig
    let selectedApiKeyId: String?
    let onSelectApiKey: (String) -> Void

    var body: some View {
        panelContent
            .frame(width: 220)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            keyList
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            ProviderIcon(providerId: provider.id, size: 14)
            Text(provider.name)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var keyList: some View {
        VStack(spacing: 0) {
            if provider.apiKeys.isEmpty {
                emptyState
            } else {
                ForEach(provider.apiKeys) { key in
                    keyButton(for: key)
                }
            }
        }
    }

    private var emptyState: some View {
        Text("No API keys")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
    }

    private func keyButton(for key: ApiKeyConfig) -> some View {
        Button {
            onSelectApiKey(key.id)
        } label: {
            keyLabel(for: key)
        }
        .buttonStyle(.plain)
    }

    private func keyLabel(for key: ApiKeyConfig) -> some View {
        HStack(spacing: 8) {
            keyIcon(for: key)
            Text(key.name)
                .font(.system(size: 12))
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(key.id == selectedApiKeyId ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    private func keyIcon(for key: ApiKeyConfig) -> some View {
        let isSelected = key.id == selectedApiKeyId
        let iconName = isSelected ? "checkmark.circle.fill" : "circle"
        let style: any ShapeStyle = isSelected ? Color.accentColor : Color.secondary
        return Image(systemName: iconName)
            .font(.system(size: 14))
            .foregroundStyle(style)
    }
}

#Preview {
    ProviderListView()
        .preferredColorScheme(.dark)
}
