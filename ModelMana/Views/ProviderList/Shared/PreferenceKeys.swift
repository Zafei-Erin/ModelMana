//
//  PreferenceKeys.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

struct ButtonFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
