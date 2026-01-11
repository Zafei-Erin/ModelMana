//
//  ModelManaApp.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import SwiftUI
import AppKit

// Helper to set window level for macOS 14.6 compatibility
struct WindowLevelAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.level = .floating
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

@main
struct ModelManaApp: App {
    var body: some Scene {
        MenuBarExtra("ModelMana", systemImage: "circle.fill") {
            ProviderListView()
        }
        .menuBarExtraStyle(.window)

        Window("Provider Settings", id: "settings") {
            SettingsWindowView()
                .background(WindowLevelAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 380)
    }
}
