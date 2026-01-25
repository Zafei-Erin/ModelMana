//
//  ClaudeProviderPanel.swift
//  ModelMana
//
//  Claude provider dropdown panel
//

import SwiftUI

struct ClaudeProviderPanel: View {
    @ObservedProvider private var provider: ClaudeProvider

    init(provider: ClaudeProvider) {
        self.provider = provider
    }

    private var selectedApiKeyId: String? {
        ProviderRegistry.shared.configuration.selectedApiKeyId
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
        if provider.config.apiKeys.isEmpty {
            emptyApiKeysCard
        } else {
            ForEach(provider.config.apiKeys, id: \.id) { key in
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
        let isSelected = provider.selectedCredential?.isManualKey(selectedId: selectedApiKeyId) == true
            && selectedApiKeyId == key.id
        let quota = provider.quota(for: key.id)
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
                selectApiKey(key.id)
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
            isSelected: provider.selectedCredential == .subscription,
            actionType: .chevron,
            isLoading: provider.loginState.isProcessing && provider.loginState.method == .subscription,
            action: {
                provider.startLogin(method: .subscription)
            }
        )
    }

    private var subscriptionCardSubtitle: String {
        if isSubscriptionLoggedIn {
            return "Pro, Max, Team, or Enterprise"
        }
        return "Login to use your subscription"
    }

    private var subscriptionProgressValue: Double? {
        guard isSubscriptionLoggedIn,
              let usage = provider.subscriptionUsage?.fiveHour?.utilization else {
            return nil
        }
        return usage
    }

    private var subscriptionProgressText: String? {
        guard isSubscriptionLoggedIn,
              let usage = provider.subscriptionUsage?.fiveHour?.utilization else {
            return nil
        }
        return "\(Int(usage))%"
    }

    private var isSubscriptionLoggedIn: Bool {
        ClaudeSessionService.isLoggedIn()
    }

    // MARK: - Console Card

    private var consoleCard: some View {
        ClaudeCredentialCard(
            title: "Console",
            subtitle: consoleCardSubtitle,
            progressValue: nil,
            progressText: consoleCostText,
            isSelected: provider.selectedCredential == .console,
            actionType: .chevron,
            isLoading: provider.loginState.isProcessing && provider.loginState.method == .console,
            action: {
                provider.startLogin(method: .console)
            }
        )
    }

    private var consoleCardSubtitle: String {
        if provider.consoleMetrics != nil {
            return "API usage billing"
        }
        return "Login to track console costs"
    }

    private var consoleCostText: String? {
        guard let metrics = provider.consoleMetrics else {
            return nil
        }
        return metrics.formattedCost
    }

    // MARK: - Actions

    private func selectApiKey(_ apiKeyId: String) {
        provider.selectedCredential = .manualKey(apiKeyId)
        ProviderRegistry.shared.selectApiKey(apiKeyId)
        ProviderRegistry.shared.selectProvider(provider.id)
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
