# Claude Dropdown Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Consolidate Claude login and cost tracking into a single dropdown panel, and ensure Claude always appears in the Available Providers list.

**Architecture:** Modify `ProviderListView` to always show Claude in provider list. Create new `ClaudeDropdownPanel` component that combines API keys, Subscription login, and Console login. Add credential selection tracking to distinguish between manual keys and OAuth-based auth.

**Tech Stack:** SwiftUI, macOS Keychain Services, Claude CLI integration

---

## Task 1: Add Claude Credential Type to AppState

**Files:**
- Modify: `ModelMana/ViewModels/AppState.swift`

**Step 1: Add credential type enum and state tracking**

Add to `AppState.swift` after the `@Observable` class declaration:

```swift
// MARK: - Claude Credential Type

enum ClaudeCredentialType: Equatable {
    case manualKey(String)  // apiKeyId
    case subscription
    case console
}
```

Add new properties to `AppState` class (after `lastCostUpdate`):

```swift
// Track which Claude credential type is currently selected
var selectedClaudeCredential: ClaudeCredentialType? = nil

// Track subscription usage (for display in dropdown)
var subscriptionUsage: ClaudeOAuthUsageResponse? = nil

// Track subscription login status separately
var isSubscriptionLoggedIn: Bool = false
```

**Step 2: Run build to verify it compiles**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ModelMana/ViewModels/AppState.swift
git commit -m "feat: add Claude credential type tracking to AppState"
```

---

## Task 2: Modify SettingsFileService to Support Keychain Auth

**Files:**
- Modify: `ModelMana/Services/SettingsFileService.swift`

**Step 1: Add new method to write keychain auth mode**

Add to `SettingsFileService` (after `writeSettings` function):

```swift
/// Write Claude settings for keychain-based auth (Subscription/Console)
/// This sets empty strings to allow Claude CLI to use Keychain credentials
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

    // Set empty env values to force keychain fallback
    existing["env"] = [
        "ANTHROPIC_AUTH_TOKEN": "",
        "ANTHROPIC_BASE_URL": "",
        "API_TIMEOUT_MS": "3000000",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1
    ]

    // Write file
    let newData = try JSONSerialization.data(withJSONObject: existing, options: .prettyPrinted)
    try newData.write(to: path)
    print("[SettingsFileService] Keychain auth settings written")

    // Configure claude.json
    try configureClaudeJson()
}
```

**Step 2: Run build to verify**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ModelMana/Services/SettingsFileService.swift
git commit -m "feat: add keychain auth mode to SettingsFileService"
```

---

## Task 3: Modify Provider List to Always Show Claude

**Files:**
- Modify: `ModelMana/Views/ProviderListView.swift`

**Step 1: Replace `providersWithKeys` with `visibleProviders`**

Find this code in `ProviderListView`:

```swift
// Filter out providers with API keys
private var providersWithKeys: [ProviderConfig] {
    AppState.shared.configuration.providers.filter { !$0.apiKeys.isEmpty }
}
```

Replace with:

```swift
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
```

**Step 2: Update ForEach to use `visibleProviders`**

Find:

```swift
ForEach(Array(providersWithKeys.enumerated()), id: \.element.id)
```

Replace with:

```swift
ForEach(Array(visibleProviders.enumerated()), id: \.element.id)
```

And update the loop variable reference from `providersWithKeys.count` to `visibleProviders.count` in the padding condition.

**Step 3: Update the empty state check**

Find:

```swift
if providersWithKeys.isEmpty {
```

Replace with:

```swift
if visibleProviders.isEmpty {
```

**Step 4: Run build to verify**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add ModelMana/Views/ProviderListView.swift
git commit -m "feat: Claude always shows in available providers"
```

---

## Task 4: Create ClaudeDropdownPanel Component

**Files:**
- Modify: `ModelMana/Views/ProviderListView.swift`

**Step 1: Create the ClaudeDropdownPanel component**

Add this component after `ApiKeyDropdownPanel` (around line 545):

```swift
// MARK: - Claude Dropdown Panel

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            apiKeySection
            Divider()
            subscriptionSection
            Divider()
            consoleSection
        }
        .frame(width: 260)
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

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("API Keys")

            if provider.apiKeys.isEmpty {
                emptyKeysState
            } else {
                keyList
            }
        }
    }

    private var emptyKeysState: some View {
        Text("No API keys")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    private var keyList: some View {
        VStack(spacing: 0) {
            ForEach(Array(provider.apiKeys.enumerated()), id: \.element.id) { index, key in
                keyButton(for: key)
                if index < provider.apiKeys.count - 1 {
                    Divider()
                        .padding(.horizontal, 6)
                }
            }
        }
    }

    private func keyButton(for key: ApiKeyConfig) -> some View {
        Button(action: { onSelectApiKey(key.id) }) {
            keyLabel(for: key)
        }
        .buttonStyle(.plain)
    }

    private func keyLabel(for key: ApiKeyConfig) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                keyIcon(for: key)
                Text(key.name)
                    .font(.system(size: 11, weight: .semibold))
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
                    .scaleEffect(0.25)

            case .success(let percentage, _):
                HStack(spacing: 6) {
                    ProgressView(value: percentage / 100, total: 1.0)
                        .progressViewStyle(BlackProgressStyle())
                        .frame(width: 80)

                    Text("\(Int(percentage))%")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                if let resetText = quota.resetTimeText {
                    Text(resetText)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }

            case .error:
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                    Text("failed")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.leading, 20)
    }

    private func keyIcon(for key: ApiKeyConfig) -> some View {
        let isSelected = key.id == selectedApiKeyId &&
                         selectedCredential == .manualKey(key.id)
        let iconName = isSelected ? "checkmark.circle.fill" : "circle"
        return Image(systemName: iconName)
            .font(.system(size: 12))
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeaderWithCheck(
                "Subscription",
                isSelected: selectedCredential == .subscription
            )

            if AppState.shared.isSubscriptionLoggedIn {
                subscriptionUsageView
            } else {
                subscriptionLoginButton
            }
        }
    }

    private var subscriptionLoginButton: some View {
        Button(action: onSelectSubscription) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Login with Subscription")
                        .font(.system(size: 11))
                    Text("Pro, Max, Team, or Enterprise")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var subscriptionUsageView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let usage = AppState.shared.subscriptionUsage,
               let fiveHour = usage.fiveHour {
                HStack(spacing: 6) {
                    ProgressView(value: (fiveHour.utilization ?? 0) / 100, total: 1.0)
                        .progressViewStyle(BlackProgressStyle())
                        .frame(width: 80)

                    if let utilization = fiveHour.utilization {
                        Text("\(Int(utilization))%")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 20)

                if let resetsAt = fiveHour.resetsAt,
                   let date = ClaudeOAuthUsageFetcher.parseISO8601Date(resetsAt) {
                    Text("Resets \(date, style: .relative) from now")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                }
            } else {
                Text("Loading usage...")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Console Section

    private var consoleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeaderWithCheck(
                "Console",
                isSelected: selectedCredential == .console
            )

            if AppState.shared.claudeConsoleMetrics != nil {
                consoleCostView
            } else {
                consoleLoginButton
            }
        }
    }

    private var consoleLoginButton: some View {
        Button(action: onSelectConsole) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Login with Console")
                        .font(.system(size: 11))
                    Text("API usage billing")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var consoleCostView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let metrics = AppState.shared.claudeConsoleMetrics {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text(metrics.formattedCost)
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                if let updateDate = AppState.shared.lastCostUpdate {
                    Text(updateTimeText(updateDate))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                }
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

    // MARK: - Section Headers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }

    private func sectionHeaderWithCheck(_ title: String, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
            }
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
```

**Step 2: Fix the font weight typo**

Find `.font(.system(size: 10, weight: medium))` and change to:

```swift
.font(.system(size: 10, weight: .medium))
```

**Step 3: Run build to verify**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ModelMana/Views/ProviderListView.swift
git commit -m "feat: add ClaudeDropdownPanel component"
```

---

## Task 5: Modify ApiKeyDropdownPanel to Use ClaudeDropdownPanel

**Files:**
- Modify: `ModelMana/Views/ProviderListView.swift`

**Step 1: Add Claude detection and callbacks to ApiKeyDropdownPanel**

Find the `ApiKeyDropdownPanel` struct. Update its body to conditionally show `ClaudeDropdownPanel`:

```swift
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
```

**Step 2: Extract existing body content to `existingPanelContent`**

Move the existing `panelContent` variable to a computed property named `existingPanelContent`:

```swift
private var existingPanelContent: some View {
    VStack(alignment: .leading, spacing: 0) {
        header
        keyList
    }
}
```

**Step 3: Add callback handlers**

Add these helper methods to `ApiKeyDropdownPanel` (before the closing brace):

```swift
private func selectApiKey(apiKeyId: String) {
    onSelectApiKey(apiKeyId)
}

private func selectSubscription() {
    AppState.shared.startClaudeLogin(method: .subscription)
}

private func selectConsole() {
    AppState.shared.startClaudeLogin(method: .console)
}
```

**Step 4: Run build to verify**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add ModelMana/Views/ProviderListView.swift
git commit -m "feat: use ClaudeDropdownPanel for Claude provider"
```

---

## Task 6: Remove Standalone Claude Login and Cost Sections

**Files:**
- Modify: `ModelMana/Views/ProviderListView.swift`

**Step 1: Remove Claude Login section from main panel**

Find and remove this entire section (around lines 126-149):

```swift
// Claude Login Section
VStack(alignment: .leading, spacing: 0) {
    Text("Claude Login")
        .font(.system(size: 12))
        .padding(.bottom, 8)

    ClaudeLoginButton(
        method: .subscription,
        title: "Login with Subscription",
        subtitle: "Pro, Max, Team, or Enterprise"
    )

    ClaudeLoginButton(
        method: .console,
        title: "Login with Console",
        subtitle: "API usage billing"
    )

    // 登录状态指示器
    if AppState.shared.claudeLoginState.isProcessing {
        ClaudeLoginStatusView(phase: AppState.shared.claudeLoginState.phase)
            .padding(.top, 4)
    }
}
```

And the divider before it (around line 125):

```swift
Divider().padding(.vertical, 6)
```

**Step 2: Remove Console Cost section from main panel**

Find and remove this entire section (around lines 153-164):

```swift
// Claude Console Cost Section
VStack(alignment: .leading, spacing: 0) {
    HStack(spacing: 4) {
        Text("本月成本")
            .font(.system(size: 12))
        Spacer()
        costRefreshButton
    }
    .padding(.bottom, 8)

    ClaudeCostView()
}
```

And the divider before it (around line 152):

```swift
Divider().padding(.vertical, 6)
```

**Step 3: Run build to verify**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 4: Test the UI**

Run the app and verify:
- Claude appears in Available Providers even without keys
- Clicking Claude shows the dropdown with 3 sections
- Login buttons work

**Step 5: Commit**

```bash
git add ModelMana/Views/ProviderListView.swift
git commit -m "refactor: remove standalone Claude login and cost sections"
```

---

## Task 7: Update AppState to Handle Credential Selection

**Files:**
- Modify: `ModelMana/ViewModels/AppState.swift`

**Step 1: Update `startClaudeLogin` to track credential and usage**

Find the `startClaudeLogin` method and update it:

```swift
func startClaudeLogin(method: ClaudeLoginMethod) {
    print("[AppState] startClaudeLogin called with method: \(method.displayName)")

    // Set initial state
    claudeLoginState = ClaudeLoginState(phase: .requesting, method: method)

    Task {
        do {
            try await ClaudeLoginService.shared.startLogin(method: method) { [self] newPhase in
                Task { @MainActor in
                    claudeLoginState.phase = newPhase
                }
            }
            // Success - update state
            Task { @MainActor in
                claudeLoginState.phase = .success

                // Set selected credential
                switch method {
                case .subscription:
                    selectedClaudeCredential = .subscription
                    isSubscriptionLoggedIn = true
                    // Fetch usage for display
                    do {
                        let usage = try await ClaudeSessionService.refreshUsage()
                        subscriptionUsage = usage
                    } catch {
                        print("[AppState] Failed to fetch subscription usage: \(error)")
                    }
                case .console:
                    selectedClaudeCredential = .console
                    // Refresh console cost
                    refreshClaudeConsoleCost()
                }

                // Write keychain auth settings
                try? SettingsFileService.writeKeychainAuthSettings()
            }
            print("[AppState] Login completed successfully")
        } catch {
            print("[AppState] Login error: \(error.localizedDescription)")
            Task { @MainActor in
                claudeLoginState.phase = .failed(error.localizedDescription)
            }
        }
    }
}
```

**Step 2: Run build to verify**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ModelMana/ViewModels/AppState.swift
git commit -m "feat: track selected Claude credential on login"
```

---

## Task 8: Update API Key Selection to Track Credential Type

**Files:**
- Modify: `ModelMana/Views/ProviderListView.swift`

**Step 1: Update `selectApiKey` function**

Find the `selectApiKey` function in `ProviderListView` and update it:

```swift
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

        // Track credential type if this is Claude
        if providerConfig.id == "claude" {
            AppState.shared.selectedClaudeCredential = .manualKey(apiKeyId)
        }

        print("[ModelMana] Selected: \(providerConfig.name) / \(apiKeyConfig.name)")
    } catch {
        print("[ModelMana] ERROR: \(error.localizedDescription)")
    }
}
```

**Step 2: Run build to verify**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ModelMana/Views/ProviderListView.swift
git commit -m "feat: track credential type when selecting Claude API key"
```

---

## Task 9: Update Settings Provider Selection to Track Credential Type

**Files:**
- Modify: `ModelMana/Views/SettingsWindowView.swift`

**Step 1: Update `selectKey` in ProviderSettingsCard**

Find the `selectKey` function in `ProviderSettingsCard` and update:

```swift
private func selectKey(_ id: String) {
    var newConfig = appState.configuration
    if let providerIndex = newConfig.providers.firstIndex(where: { $0.id == provider.id }) {
        newConfig.providers[providerIndex].apiKeys = apiKeys
    } else {
        // Provider 不在配置中（preset provider 首次选择），先添加到配置
        newConfig.providers.append(
            ProviderConfig(
                id: provider.id,
                name: provider.name,
                baseUrl: provider.baseUrl,
                apiKeys: apiKeys
            ))
    }
    newConfig.selectedProviderId = provider.id
    newConfig.selectedApiKeyId = id
    appState.configuration = newConfig
    try? ConfigService.saveConfiguration(appState.configuration)

    // Track credential type if this is Claude
    if provider.id == "claude" {
        AppState.shared.selectedClaudeCredential = .manualKey(id)
    }
}
```

**Step 2: Run build to verify**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ModelMana/Views/SettingsWindowView.swift
git commit -m "feat: track Claude credential type in settings"
```

---

## Task 10: Final Build and Test

**Step 1: Full build**

```bash
xcodebuild build -project ModelMana.xcodeproj -scheme ModelMana
```

Expected: BUILD SUCCEEDED

**Step 2: Manual testing checklist**

- [ ] Claude appears in Available Providers (even with 0 API keys)
- [ ] Clicking Claude shows dropdown with 3 sections
- [ ] API Keys section shows keys or "No API keys"
- [ ] Subscription login button works and shows usage after login
- [ ] Console login button works and shows cost after login
- [ ] Blue checkmark shows on selected credential
- [ ] Manual API key selection works and shows checkmark
- [ ] Settings window still works for adding keys

**Step 3: Final commit**

```bash
git add .
git commit -m "docs: complete Claude dropdown redesign"
```
