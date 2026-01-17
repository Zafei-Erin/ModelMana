//
//  ClaudeLoginComponents.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

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
