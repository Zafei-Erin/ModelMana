//
//  ApiKeyRow.swift
//  ModelMana
//
//  Created by refactoring from SettingsWindowView
//

import SwiftUI

struct ApiKeyRow: View {
    let keyConfig: ApiKeyConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 8) {
            // Selection indicator (clickable)
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            // Key name and masked/full key (clickable)
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(keyConfig.name)
                        .font(.caption)
                        .foregroundColor(.primary)
                    if isRevealed {
                        Text(keyConfig.key)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    } else {
                        Text(keyConfig.maskedKey)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // View button (toggle visibility)
            Button(action: {
                isRevealed.toggle()
            }) {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
    }
}
