//
//  ProviderButton.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

struct ProviderButton: View {
    let providerConfig: ProviderConfig
    let onTap: () -> Void

    var body: some View {
        HoverButton(action: onTap) {
            HStack(spacing: 12) {
                ProviderIcon(providerId: providerConfig.id, size: 12)
                Text(providerConfig.name)
                    .font(.system(size: 12))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}
