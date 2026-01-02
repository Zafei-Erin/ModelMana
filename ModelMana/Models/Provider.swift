//
//  Provider.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import Foundation

enum Provider: String, CaseIterable, Identifiable {
    case zhipu = "智谱 AI"
    case openai = "OpenAI"

    var id: String { rawValue }

    var baseURL: String {
        switch self {
        case .zhipu:
            return "https://open.bigmodel.cn/api/anthropic"
        case .openai:
            return "https://api.openai.com/v1"
        }
    }

    var envKey: String {
        switch self {
        case .zhipu:
            return "ZHIPU_API_KEY"
        case .openai:
            return "OPENAI_API_KEY"
        }
    }
}
