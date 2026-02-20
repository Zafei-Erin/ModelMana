//
//  ApiKeyDropdownPanel.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

struct ApiKeyDropdownPanel: View {
    let provider: ProviderConfig
    let onSelectApiKey: (String) -> Void

    // Directly from AppState read current selected API Key ID
    private var selectedApiKeyId: String? {
        AppState.shared.configuration.selectedApiKeyId
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
        let state: QuotaState = {
            switch provider.id {
            case "zhipu":
                return ProviderRegistry.shared.zhipu.quota(for: key.id)
            case "minimax":
                return ProviderRegistry.shared.minimax.quota(for: key.id)
            case "claude":
                return ProviderRegistry.shared.claude.quota(for: key.id)
            default:
                return .loaded([])
            }
        }()

        switch state {
        case .loading:
            ProgressView()
                .scaleEffect(0.3)
                .padding(.leading, 24)
                .padding(.top, 6)

        case .loaded(let items):
            if items.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        renderQuotaItem(item)
                    }
                }
                .padding(.leading, 24)
                .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    private func renderQuotaItem(_ item: QuotaItem) -> some View {
        switch item.status {
        case .success(let percentage, _):
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(item.title)
                        .font(.system(size: 11))
                    Spacer()
                    if let resetText = item.resetTimeText {
                        Text(resetText)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ProgressView(value: percentage / 100, total: 1.0)
                        .progressViewStyle(BlackProgressStyle())
                    Text("\(Int(percentage))%")
                        .font(.system(size: 9))
                }
                .frame(height: 12)
            }

        case .error:
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.system(size: 11))
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                    Text("failed to fetch")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func keyIcon(for key: ApiKeyConfig) -> some View {
        let isSelected = key.id == selectedApiKeyId
        let iconName = isSelected ? "checkmark.circle.fill" : "circle"
        return Image(systemName: iconName)
            .font(.system(size: 14))
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
    }
}
