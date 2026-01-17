//
//  CostLoadingState.swift
//  ModelMana
//
//  Created by refactoring from AppState.swift
//

import Foundation

/// Cost loading state for Claude Console
enum CostLoadingState: Equatable {
    case idle
    case loading
    case success
    case error(String)

    static func == (lhs: CostLoadingState, rhs: CostLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.success, .success):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
