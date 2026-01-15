//
//  Provider.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import Foundation

enum Provider: String, CaseIterable, Identifiable {
    case zhipu = "Zhipu"
    case claude = "Claude"
    case minimax = "Minimax"

    // 使用固定 id，不随显示名称变化
    var id: String {
        switch self {
        case .zhipu: return "zhipu"
        case .claude: return "claude"
        case .minimax: return "minimax"
        }
    }

    var baseURL: String {
        switch self {
        case .zhipu:
            return "https://open.bigmodel.cn/api/anthropic"
        case .claude:
            return "https://api.anthropic.com"
        case .minimax:
            return "https://api.minimaxi.com/anthropic"
        }
    }

    var envKey: String {
        switch self {
        case .zhipu:
            return "ZHIPU_API_KEY"
        case .claude:
            return "CLAUDE_API_KEY"
        case .minimax:
            return "MINIMAX_API_KEY"
        }
    }
}
