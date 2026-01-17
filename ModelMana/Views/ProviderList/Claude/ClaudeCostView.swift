//
//  ClaudeCostView.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

struct ClaudeCostView: View {
    private var state: AppState { AppState.shared }

    var body: some View {
        let costState = state.costLoadingState

        switch costState {
        case .idle:
            idleView
        case .loading:
            loadingView
        case .success:
            successView
        case .error(let message):
            errorView(message)
        }
    }

    private var idleView: some View {
        HStack(spacing: 6) {
            Image(systemName: "dashlane")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("点击刷新获取成本")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var loadingView: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.4)
            Text("获取中...")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var successView: some View {
        if let metrics = state.claudeConsoleMetrics {
            VStack(alignment: .leading, spacing: 2) {
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
            }
        } else {
            Text("无数据")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.red)
            Text(getShortErrorMessage(message))
                .font(.system(size: 11))
                .foregroundStyle(.red)
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
