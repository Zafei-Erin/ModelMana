//
//  ProgressViews.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

/// Reusable quota progress view with size variants
struct QuotaProgressView: View {
    let item: QuotaItem
    var style: QuotaProgressStyle = .full

    enum QuotaProgressStyle {
        case full    // Shows text below progress
        case compact // Shows text beside progress
    }

    var body: some View {
        switch item.status {
        case .success(let percentage, _):
            successView(percentage: percentage)

        case .error:
            errorView
        }
    }

    @ViewBuilder
    private func successView(percentage: Double) -> some View {
        if style == .compact {
            compactSuccessView(percentage: percentage)
        } else {
            fullSuccessView(percentage: percentage)
        }
    }

    @ViewBuilder
    private func compactSuccessView(percentage: Double) -> some View {
        HStack(spacing: 8) {
            ProgressView(value: percentage / 100, total: 1.0)
                .progressViewStyle(BlackProgressStyle())

            Text("\(Int(percentage))%")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }

        if let resetText = item.resetTimeText {
            Text(resetText)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func fullSuccessView(percentage: Double) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                ProgressView(value: percentage / 100, total: 1.0)
                    .progressViewStyle(BlackProgressStyle())

                Text("\(Int(percentage))%")
                    .font(.system(size: 11))
                    .fontWeight(.medium)
            }

            if let resetText = item.resetTimeText {
                Text(resetText)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var errorView: some View {
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
