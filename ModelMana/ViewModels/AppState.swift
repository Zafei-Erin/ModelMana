//
//  AppState.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import SwiftUI

@Observable
class AppState {
    static let shared = AppState()

    var configuration: AppConfiguration

    private init() {
        configuration = ConfigService.loadConfiguration()
    }
}
