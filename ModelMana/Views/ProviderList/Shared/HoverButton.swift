//
//  HoverButton.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

struct HoverButton<Content: View>: View {
    var isSelected: Bool = false
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var isHovering = false
    @State private var isPressing = false

    var body: some View {
        Button(action: action) {
            content()
                .background(backgroundForState)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .onPressGesture { pressing in
            isPressing = pressing
        }
    }

    private var backgroundForState: Color {
        if isPressing {
            return Color.gray.opacity(0.15)
        } else if isHovering {
            return Color.gray.opacity(0.1)
        }
        return Color.clear
    }
}
