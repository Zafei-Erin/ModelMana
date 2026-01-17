//
//  EnvService.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import Foundation

struct EnvService {
    /// 读取环境变量
    /// - Parameter key: 环境变量名
    /// - Returns: 环境变量值，如果不存在则返回 nil
    static func read(_ key: String) -> String? {
        return ProcessInfo.processInfo.environment[key]
    }
}
