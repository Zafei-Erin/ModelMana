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
        .menuBarExtraStyle(.window)

        Window("Provider Settings", id: "settings") {
            SettingsWindowView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 380)
    }
}
