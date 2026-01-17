//
//  ClaudeCredentialCard.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

enum ClaudeCardActionType {
    case checkmark  // For API Keys - shows selection state
    case chevron    // For Subscription/Console - navigation to login
}

struct ClaudeCredentialCard: View {
    let title: String
    let subtitle: String
    let progressValue: Double?  // Percentage for API Keys/Subscription
    let progressText: String?   // Display text (e.g., "29%" or "$10.65")
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
