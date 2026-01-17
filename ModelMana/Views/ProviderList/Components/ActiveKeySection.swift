//
//  ActiveKeySection.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

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
