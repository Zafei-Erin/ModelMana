//
//  ViewExtensions.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

extension View {
    func onPressGesture(change: @escaping (Bool) -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    change(true)
                }
                .onEnded { _ in
                    change(false)
                }
        )
    }
}
