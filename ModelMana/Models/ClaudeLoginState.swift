//
//  ClaudeLoginState.swift
//  ModelMana
//
//  Created by Claude on 1/12/26.
//

import Foundation

/// Claude 登录方式选择
enum ClaudeLoginMethod: String {
    case subscription = "1"  // Claude account with subscription
    case console = "2"       // Anthropic Console account

    var displayName: String {
        switch self {
        case .subscription: return "Subscription"
        case .console: return "Console"
        }
    }
}

/// Claude 登录阶段
enum ClaudeLoginPhase: Equatable {
    case idle
    case requesting           // 启动 claude /login
    case waitingBrowser       // 等待用户在浏览器完成登录
    case success
    case failed(String)
}

/// Claude 登录状态
struct ClaudeLoginState: Equatable {
    var phase: ClaudeLoginPhase = .idle
    var method: ClaudeLoginMethod?
    var oauthUrl: String?

    /// 是否正在处理中
    var isProcessing: Bool {
        switch phase {
        case .requesting, .waitingBrowser:
            return true
        default:
            return false
        }
    }
}
