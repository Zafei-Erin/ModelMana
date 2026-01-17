//
//  AddApiKeyForm.swift
//  ModelMana
//
//  Created by refactoring from SettingsWindowView
//

import SwiftUI

struct AddApiKeyForm: View {
    @Binding var name: String
    @Binding var key: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name input
            HStack {
                Text("Name:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                TextField("Key name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.caption)
            }

            // Key input
            HStack {
                Text("Key:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                SecureField("sk-...", text: $key)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
            }

            // Buttons
            HStack(spacing: 8) {
                Button(action: onSave) {
                    Text("Add")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(key.isEmpty)

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}
