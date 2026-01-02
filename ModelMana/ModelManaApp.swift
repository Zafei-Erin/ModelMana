//
//  ModelManaApp.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import SwiftUI

@main
struct ModelManaApp: App {
    var body: some Scene {
        MenuBarExtra("ModelMana", systemImage: "circle.fill") {
            ProviderListView()
        }

        Window("Provider Settings", id: "settings") {
            SettingsWindowView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 350)
    }
}
