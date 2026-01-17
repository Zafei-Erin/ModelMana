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
                        })?.name ?? "Default",
                        apiKeyId: config.selectedApiKeyId
                    )
                    .padding(.horizontal, 2)
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
                    if visibleProviders.isEmpty {
                        // 空状态 - 没有provider有API key
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

        let currentCredential = AppState.shared.selectedClaudeCredential
        print(
            "[ModelMana] Current credential: \(String(describing: currentCredential)), switching to: \(providerConfig.id)"
        )

        // If switching away from Claude subscription/console, delete keychain entry
        if case .subscription = currentCredential {
            if providerConfig.id != "claude" {
                print(
                    "[ModelMana] Switching from subscription to \(providerConfig.id), deleting keychain"
                )
                SettingsFileService.deleteClaudeKeychainEntry()
                AppState.shared.isSubscriptionLoggedIn = false
            }
        } else if case .console = currentCredential {
            if providerConfig.id != "claude" {
                print(
                    "[ModelMana] Switching from console to \(providerConfig.id), deleting keychain")
                SettingsFileService.deleteClaudeKeychainEntry()
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

        let contentView = NSHostingView(
            rootView: ApiKeyDropdownPanel(
                provider: provider,
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
    let apiKeyId: String?

    private var credentialType: ClaudeCredentialType? {
        AppState.shared.selectedClaudeCredential
    }

    var body: some View {
        HStack(spacing: 12) {
            ProviderIcon(providerId: providerId, size: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 12))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Only show left-side progress for non-Claude providers
                if providerId != "claude" {
                    quotaProgressView(for: apiKeyId)
                }
            }

            Spacer()

            // Right side info for Claude (all credential types)
            if providerId == "claude", let credential = credentialType {
                rightSideInfo(for: credential)
            }
        }
    }

    private var displayName: String {
        if providerId == "claude", let credential = credentialType {
            switch credential {
            case .manualKey:
                return "\(providerName) - \(apiKeyName)"
            case .subscription:
                return "\(providerName) - Subscription"
            case .console:
                return "\(providerName) - Console"
            }
        }
        return "\(providerName) - \(apiKeyName)"
    }

    @ViewBuilder
    private func rightSideInfo(for credential: ClaudeCredentialType) -> some View {
        switch credential {
        case .manualKey:
            manualKeyRightSideInfo
        case .subscription:
            subscriptionRightSideInfo
        case .console:
            consoleRightSideInfo
        }
    }

    private var manualKeyRightSideInfo: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let apiKeyId {
                let quota = AppState.shared.getQuota(for: apiKeyId)
                switch quota.status {
                case .loading:
                    ProgressView()
                        .scaleEffect(0.5)
                case .success(let percentage, _):
                    HStack(spacing: 6) {
                        ProgressView(value: percentage / 100, total: 1.0)
                            .progressViewStyle(BlackProgressStyle())

                        Text("\(Int(percentage))%")
                            .font(.system(size: 11))
                            .fontWeight(.medium)
                    }
                    if let resetText = quota.resetTimeText {
                        Text(resetText)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                case .error:
                    Text("Error")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var subscriptionRightSideInfo: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let usage = AppState.shared.subscriptionUsage,
                let fiveHour = usage.fiveHour
            {
                HStack(spacing: 6) {
                    ProgressView(value: (fiveHour.utilization ?? 0) / 100, total: 1.0)
                        .progressViewStyle(BlackProgressStyle())

                    if let utilization = fiveHour.utilization {
                        Text("\(Int(utilization))%")
                            .font(.system(size: 11))
                            .fontWeight(.medium)
                    }
                }
                if let resetsAt = fiveHour.resetsAt,
                    let date = ClaudeOAuthUsageFetcher.parseISO8601Date(resetsAt)
                {
                    Text(resetsInText(date))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Loading...")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var consoleRightSideInfo: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let metrics = AppState.shared.claudeConsoleMetrics {
                Text(metrics.formattedCost)
                    .font(.system(size: 11))
                    .fontWeight(.medium)

                if let updateDate = AppState.shared.lastCostUpdate {
                    Text(updateTimeText(updateDate))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Loading...")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resetsInText(_ date: Date) -> String {
        let now = Date()
        let interval = date.timeIntervalSinceNow

        if interval <= 0 {
            return "Resets soon"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "Resets in \(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "Resets in \(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "Resets in \(days)d"
        }
    }

    private func updateTimeText(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }

    @ViewBuilder
    private func quotaProgressView(for apiKeyId: String?) -> some View {
        if let apiKeyId {
            let quota = AppState.shared.getQuota(for: apiKeyId)

            switch quota.status {
            case .loading:
                ProgressView()
                    .scaleEffect(0.3)

            case .success(let percentage, _):
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        ProgressView(value: percentage / 100, total: 1.0)
                            .progressViewStyle(BlackProgressStyle())

                        Text("\(Int(percentage))%")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    if let resetText = quota.resetTimeText {
                        Text(resetText)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

            case .error:
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                    Text("failed to fetch")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
            }
        }
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
        } else if providerId == "minimax" {
            Image("minimax")
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
        HoverButton(action: onTap) {
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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

// API Key 下拉面板
struct ApiKeyDropdownPanel: View {
    let provider: ProviderConfig
    let onSelectApiKey: (String) -> Void

    // 直接从 AppState 读取当前选中的 API Key ID
    private var selectedApiKeyId: String? {
        AppState.shared.configuration.selectedApiKeyId
    }

    var body: some View {
        if provider.id == "claude" {
            ClaudeDropdownPanel(
                provider: provider,
                onSelectApiKey: { apiKeyId in
                    selectApiKey(apiKeyId: apiKeyId)
                },
                onSelectSubscription: {
                    selectSubscription()
                },
                onSelectConsole: {
                    selectConsole()
                }
            )
        } else {
            existingPanelContent
        }
    }

    private var existingPanelContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            keyList
        }
        .frame(width: 220)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }

    private var header: some View {
        Text(provider.name)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    private var keyList: some View {
        VStack(spacing: 0) {
            if provider.apiKeys.isEmpty {
                emptyState
            } else {
                ForEach(Array(provider.apiKeys.enumerated()), id: \.element.id) { index, key in
                    keyButton(for: key)
                    if index < provider.apiKeys.count - 1 {
                        Divider()
                            .padding(.horizontal, 6)
                    }
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
        HoverButton(
            isSelected: key.id == selectedApiKeyId,
            action: {
                onSelectApiKey(key.id)
            }
        ) {
            keyLabel(for: key)
        }
    }

    private func keyLabel(for key: ApiKeyConfig) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                keyIcon(for: key)
                Text(key.name)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
            }

            quotaProgressView(for: key)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func quotaProgressView(for key: ApiKeyConfig) -> some View {
        let quota = AppState.shared.getQuota(for: key.id)

        VStack(alignment: .leading, spacing: 2) {
            switch quota.status {
            case .loading:
                ProgressView()
                    .scaleEffect(0.3)

            case .success(let percentage, _):
                HStack(spacing: 6) {
                    ProgressView(value: percentage / 100, total: 1.0)
                        .progressViewStyle(BlackProgressStyle())

                    Text("\(Int(percentage))%")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                if let resetText = quota.resetTimeText {
                    Text(resetText)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

            case .error:
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                    Text("failed to fetch")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.leading, 24)
    }

    private func keyIcon(for key: ApiKeyConfig) -> some View {
        let isSelected = key.id == selectedApiKeyId
        let iconName = isSelected ? "checkmark.circle.fill" : "circle"
        return Image(systemName: iconName)
            .font(.system(size: 14))
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
    }

    private func selectApiKey(apiKeyId: String) {
        onSelectApiKey(apiKeyId)
    }

    private func selectSubscription() {
        AppState.shared.startClaudeLogin(method: .subscription)
    }

    private func selectConsole() {
        AppState.shared.startClaudeLogin(method: .console)
    }
}

// MARK: - Claude Dropdown Panel (Card-Based Design)

struct ClaudeDropdownPanel: View {
    let provider: ProviderConfig
    let onSelectApiKey: (String) -> Void
    let onSelectSubscription: () -> Void
    let onSelectConsole: () -> Void

    private var selectedApiKeyId: String? {
        AppState.shared.configuration.selectedApiKeyId
    }

    private var selectedCredential: ClaudeCredentialType? {
        AppState.shared.selectedClaudeCredential
    }

    private var loginState: ClaudeLoginState {
        AppState.shared.claudeLoginState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(spacing: 8) {
                apiKeyCardsSection
                subscriptionCard
                consoleCard
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 220)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }

    private var header: some View {
        Text(provider.name)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    // MARK: - API Keys Section

    @ViewBuilder
    private var apiKeyCardsSection: some View {
        if provider.apiKeys.isEmpty {
            emptyApiKeysCard
        } else {
            ForEach(provider.apiKeys, id: \.id) { key in
                apiKeyCard(for: key)
            }
        }
    }

    private var emptyApiKeysCard: some View {
        ClaudeCredentialCard(
            title: "API Keys",
            subtitle: "Add keys in settings",
            progressValue: nil,
            progressText: nil,
            isSelected: false,
            actionType: .checkmark,
            isLoading: false,
            action: {}
        )
    }

    private func apiKeyCard(for key: ApiKeyConfig) -> some View {
        let isSelected =
            selectedCredential?.isManualKey(selectedId: selectedApiKeyId) == true
            && selectedApiKeyId == key.id
        let quota = AppState.shared.getQuota(for: key.id)
        var progressValue: Double?
        var progressText: String?

        if case .success(let percentage, _) = quota.status {
            progressValue = percentage
            progressText = "\(Int(percentage))%"
        }

        return ClaudeCredentialCard(
            title: key.name,
            subtitle: "API Key",
            progressValue: progressValue,
            progressText: progressText,
            isSelected: isSelected,
            actionType: .checkmark,
            isLoading: false,
            action: {
                onSelectApiKey(key.id)
            }
        )
    }

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        ClaudeCredentialCard(
            title: "Subscription",
            subtitle: subscriptionCardSubtitle,
            progressValue: subscriptionProgressValue,
            progressText: subscriptionProgressText,
            isSelected: selectedCredential == .subscription,
            actionType: .chevron,
            isLoading: loginState.isProcessing && loginState.method == .subscription,
            action: onSelectSubscription
        )
    }

    private var subscriptionCardSubtitle: String {
        if AppState.shared.isSubscriptionLoggedIn {
            return "Pro, Max, Team, or Enterprise"
        }
        return "Login to use your subscription"
    }

    private var subscriptionProgressValue: Double? {
        guard AppState.shared.isSubscriptionLoggedIn,
            let usage = AppState.shared.subscriptionUsage?.fiveHour?.utilization
        else {
            return nil
        }
        return usage
    }

    private var subscriptionProgressText: String? {
        guard AppState.shared.isSubscriptionLoggedIn,
            let usage = AppState.shared.subscriptionUsage?.fiveHour?.utilization
        else {
            return nil
        }
        return "\(Int(usage))%"
    }

    // MARK: - Console Card

    private var consoleCard: some View {
        ClaudeCredentialCard(
            title: "Console",
            subtitle: consoleCardSubtitle,
            progressValue: nil,  // Console shows cost, not percentage
            progressText: consoleCostText,
            isSelected: selectedCredential == .console,
            actionType: .chevron,
            isLoading: loginState.isProcessing && loginState.method == .console,
            action: onSelectConsole
        )
    }

    private var consoleCardSubtitle: String {
        if AppState.shared.claudeConsoleMetrics != nil {
            return "API usage billing"
        }
        return "Login to track console costs"
    }

    private var consoleCostText: String? {
        guard let metrics = AppState.shared.claudeConsoleMetrics else {
            return nil
        }
        return metrics.formattedCost
    }
}

// MARK: - Claude Credential Card

enum ClaudeCardActionType {
    case checkmark  // For API Keys - shows selection state
    case chevron  // For Subscription/Console - navigation to login
}

struct ClaudeCredentialCard: View {
    let title: String
    let subtitle: String
    let progressValue: Double?  // Percentage for API Keys/Subscription
    let progressText: String?  // Display text (e.g., "29%" or "$10.65")
    let isSelected: Bool
    let actionType: ClaudeCardActionType
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Left: Circular progress indicator
                progressIndicator

                // Middle: Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(isLoading ? "Logging in..." : subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Right: Action button (checkmark, chevron, or loading spinner)
                if isLoading {
                    loadingSpinner
                } else {
                    actionButton
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(nsColor: .controlBackgroundColor))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private var progressIndicator: some View {
        if let value = progressValue, let text = progressText {
            // Show circular progress ring
            ZStack {
                Circle()
                    .stroke(
                        Color.gray.opacity(0.2),
                        lineWidth: 2.5
                    )

                Circle()
                    .trim(from: 0, to: value / 100)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text(text)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(width: 32, height: 32)
        } else if let costText = progressText, actionType == .chevron && title == "Console" {
            // Console shows cost in circle
            ZStack {
                Circle()
                    .stroke(
                        Color.gray.opacity(0.2),
                        lineWidth: 2.5
                    )

                Text(costText)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(width: 32, height: 32)
        } else {
            // Empty circle for not logged in
            ZStack {
                Circle()
                    .stroke(
                        Color.gray.opacity(0.2),
                        lineWidth: 2.5
                    )
            }
            .frame(width: 32, height: 32)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if actionType == .checkmark || (actionType == .chevron && isSelected) {
            // Blue checkmark for selected state
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? Color.accentColor : Color.gray.opacity(0.4))
        } else {
            // Chevron for navigation when not logged in
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.gray.opacity(0.5))
        }
    }

    private var loadingSpinner: some View {
        ProgressView()
            .scaleEffect(0.5)
    }
}

// MARK: - ClaudeCredentialType Helper Extension

extension ClaudeCredentialType {
    func isManualKey(selectedId: String?) -> Bool {
        if case .manualKey(let id) = self {
            return id == selectedId
        }
        return false
    }
}

// 自定义带 hover 效果的按钮包装器
struct HoverButton<Content: View>: View {
    var isSelected: Bool = false
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var isHovering = false
    @State private var isPressing = false

    var body: some View {
        Button(action: action) {
            content()
                .background(backgroundForState)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .onPressGesture { pressing in
            isPressing = pressing
        }
    }

    private var backgroundForState: Color {
        if isPressing {
            return Color.gray.opacity(0.15)
        } else if isHovering {
            return Color.gray.opacity(0.1)
        }
        return Color.clear
    }
}

// 按压手势扩展
extension View {
    func onPressGesture(change: @escaping (Bool) -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    change(true)
                }
                .onEnded { _ in
                    change(false)
                }
        )
    }
}

// 自定义黑色进度条样式
struct BlackProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))

                    // 进度条
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.black)
                        .frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0))
                }
            }
            .frame(height: 4)
        }
    }
}

#Preview {
    ProviderListView()
        .preferredColorScheme(.dark)
}

// MARK: - Claude Console Cost View

struct ClaudeCostView: View {
    private var state: AppState { AppState.shared }

    var body: some View {
        let costState = state.costLoadingState

        switch costState {
        case .idle:
            HStack(spacing: 6) {
                Image(systemName: "dashlane")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("点击刷新获取成本")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.4)
                Text("获取中...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

        case .success:
            if let metrics = state.claudeConsoleMetrics {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                    Text(metrics.formattedCost)
                        .font(.system(size: 11))
                        .fontWeight(.semibold)
                }

                if let updateDate = state.lastCostUpdate {
                    Text(updateTimeText(updateDate))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("无数据")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

        case .error(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                Text(getShortErrorMessage(message))
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
    }

    private func updateTimeText(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }

    private func getShortErrorMessage(_ message: String) -> String {
        if message.count > 30 {
            return String(message.prefix(27)) + "..."
        }
        return message
    }
}

private var costRefreshButton: some View {
    Button(action: {
        AppState.shared.refreshClaudeConsoleCost()
    }) {
        Image(systemName: "arrow.clockwise")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .help("刷新成本数据")
}

// MARK: - Claude Login Components

struct ClaudeLoginButton: View {
    let method: ClaudeLoginMethod
    let title: String
    let subtitle: String

    private var isLoading: Bool {
        AppState.shared.claudeLoginState.isProcessing
            && AppState.shared.claudeLoginState.method == method
    }

    var body: some View {
        Button(action: {
            AppState.shared.startClaudeLogin(method: method)
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.4)
                } else {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 11))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12))
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct ClaudeLoginStatusView: View {
    let phase: ClaudeLoginPhase

    var body: some View {
        HStack(spacing: 6) {
            statusIcon
            statusText
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch phase {
        case .requesting:
            ProgressView()
                .scaleEffect(0.4)
        case .waitingBrowser:
            Image(systemName: "safari")
                .foregroundColor(.orange)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch phase {
        case .requesting:
            Text("Starting login...")
        case .waitingBrowser:
            Text("Complete login in browser")
        case .success:
            Text("Logged in successfully")
        case .failed(let message):
            Text(message)
        case .idle:
            EmptyView()
        }
    }
}
