//
//  ProviderListView.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//  Refactored: 2025-01-17
//

import AppKit
import SwiftUI

struct ProviderListView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var dropdownProvider: ProviderConfig?
    @State private var dropdownWindow: NSPanel?
    @State private var providerButtonFrames: [String: CGRect] = [:]
    @State private var eventMonitor: Any?

    // Dynamically compute current provider
    private var currentProviderConfig: ProviderConfig? {
        let config = AppState.shared.configuration
        // Prefer selectedProviderId from config
        if let selectedId = config.selectedProviderId {
            return config.providers.first { $0.id == selectedId }
        }
        // Fallback: read from file
        if let baseUrl = getCurrentProviderBaseURL() {
            return config.providers.first { $0.baseUrl == baseUrl }
        }
        return nil
    }

    // Visible providers - Claude always shows, others only if they have keys
    private var visibleProviders: [ProviderConfig] {
        let allProviders = AppState.shared.configuration.providers

        // Always include Claude (create empty config if not present)
        let claudeProvider: ProviderConfig
        if let existing = allProviders.first(where: { $0.id == "claude" }) {
            claudeProvider = existing
        } else {
            // Create empty Claude provider config
            claudeProvider = ProviderConfig(
                id: "claude",
                name: "Claude",
                baseUrl: Provider.claude.baseURL,
                apiKeys: []
            )
        }

        // Other providers only if they have keys
        let otherProviders = allProviders.filter { !$0.apiKeys.isEmpty && $0.id != "claude" }

        return [claudeProvider] + otherProviders
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider().padding(.vertical, 6)

            // Current Provider Section
            currentProviderSection

            Divider().padding(.vertical, 6)

            // Available Providers Section
            availableProvidersSection

            // Quit
            quitButton
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

    // MARK: - Header

    private var header: some View {
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
    }

    // MARK: - Current Provider Section

    private var currentProviderSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Current Provider")
                .font(.system(size: 12))
                .padding(.bottom, 8)

            if let current = currentProviderConfig {
                ActiveKeySection(
                    providerId: current.id,
                    providerName: current.name,
                    apiKeyName: current.apiKeys.first(where: {
                        $0.id == AppState.shared.configuration.selectedApiKeyId
                    })?.name ?? "Default",
                    apiKeyId: AppState.shared.configuration.selectedApiKeyId
                )
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Available Providers Section

    private var availableProvidersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Available Providers")
                .font(.system(size: 12))
                .padding(.bottom, 8)

            // Provider list
            VStack(spacing: 0) {
                if visibleProviders.isEmpty {
                    // Empty state - no provider has API keys
                    Text("Add keys in settings..")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                } else {
                    ForEach(Array(visibleProviders.enumerated()), id: \.element.id) {
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
                        .padding(.bottom, index < visibleProviders.count - 1 ? 6 : 0)
                    }
                }
            }
        }
    }

    // MARK: - Quit Button

    private var quitButton: some View {
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

    // MARK: - Dropdown Management

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

        let currentCredential = AppState.shared.selectedClaudeCredential

        // If switching away from Claude subscription/console, delete keychain entry
        if case .subscription = currentCredential {
            if providerConfig.id != "claude" {
                SettingsFileService.deleteClaudeKeychainEntry()
                AppState.shared.selectedClaudeCredential = nil
            }
        } else if case .console = currentCredential {
            if providerConfig.id != "claude" {
                SettingsFileService.deleteClaudeKeychainEntry()
                AppState.shared.selectedClaudeCredential = nil
            }
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

            // Persist configuration to disk
            try? ConfigService.saveConfiguration(newConfig)

            // Track credential type if this is Claude
            if providerConfig.id == "claude" {
                AppState.shared.selectedClaudeCredential = .manualKey(apiKeyId)
            } else {
                // Clear Claude credential when switching to other providers
                AppState.shared.selectedClaudeCredential = nil
            }

            Logger.log("Provider", "Selected: \(providerConfig.name) / \(apiKeyConfig.name)")
        } catch {
            Logger.error("Provider", error.localizedDescription)
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
        panel.hasShadow = true

        let contentView: NSHostingView<AnyView>
        if provider.id == "claude" {
            contentView = NSHostingView(
                rootView: AnyView(
                    ClaudeDropdownPanel(
                        provider: provider,
                        onSelectApiKey: { apiKeyId in
                            selectApiKey(providerConfig: provider, apiKeyId: apiKeyId)
                        },
                        onSelectSubscription: {
                            selectSubscription()
                        },
                        onSelectConsole: {
                            selectConsole()
                        }
                    )
                )
            )
        } else {
            contentView = NSHostingView(
                rootView: AnyView(
                    ApiKeyDropdownPanel(
                        provider: provider,
                        onSelectApiKey: { apiKeyId in
                            selectApiKey(providerConfig: provider, apiKeyId: apiKeyId)
                        }
                    )
                )
            )
        }

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

    private func selectSubscription() {
        AppState.shared.startClaudeLogin(method: .subscription)
    }

    private func selectConsole() {
        AppState.shared.startClaudeLogin(method: .console)
    }
}

#Preview {
    ProviderListView()
        .preferredColorScheme(.dark)
}
