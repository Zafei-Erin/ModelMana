//
//  ClaudeDropdownPanel.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

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

// MARK: - ClaudeCredentialType Helper Extension

extension ClaudeCredentialType {
    func isManualKey(selectedId: String?) -> Bool {
        if case .manualKey(let id) = self {
            return id == selectedId
        }
        return false
    }
}
