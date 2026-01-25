//
//  MinimaxProviderPanel.swift
//  ModelMana
//
//  Minimax provider dropdown panel
//

import SwiftUI

struct MinimaxProviderPanel: View {
    @ObservedProvider private var provider: MinimaxProvider

    init(provider: MinimaxProvider) {
        self.provider = provider
    }

    private var selectedApiKeyId: String? {
        ProviderRegistry.shared.configuration.selectedApiKeyId
    }

    var body: some View {
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
            if provider.config.apiKeys.isEmpty {
                emptyState
            } else {
                ForEach(Array(provider.config.apiKeys.enumerated()), id: \.element.id) { index, key in
                    keyButton(for: key)
                    if index < provider.config.apiKeys.count - 1 {
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
                selectKey(key)
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
        let quota = provider.quota(for: key.id)

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

            case .error(let message):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                    Text(message.isEmpty ? "Error" : message)
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

    // MARK: - Actions

    private func selectKey(_ key: ApiKeyConfig) {
        ProviderRegistry.shared.selectApiKey(key.id)
        ProviderRegistry.shared.selectProvider(provider.id)
    }
}
