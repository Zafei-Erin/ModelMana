//
//  CredentialEntryLayout.swift
//  ModelMana
//
//  Reusable layout skeleton for credential entries in dropdown panels
//

import SwiftUI

struct CredentialEntryLayout<Content: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        HoverButton(isSelected: isSelected, action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()
                }

                content()
                    .padding(.leading, 22)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }
}
