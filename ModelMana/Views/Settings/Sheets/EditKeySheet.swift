//
//  EditKeySheet.swift
//  ModelMana
//
//  Created by refactoring from SettingsWindowView
//

import SwiftUI

struct EditKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    let keyConfig: ApiKeyConfig
    let onSave: (String, String) -> Void

    @State private var name: String
    @State private var key: String
    @State private var isRevealed = false

    init(keyConfig: ApiKeyConfig, onSave: @escaping (String, String) -> Void) {
        self.keyConfig = keyConfig
        self.onSave = onSave
        self._name = State(initialValue: keyConfig.name)
        self._key = State(initialValue: keyConfig.key)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Edit API Key")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .leading, .trailing], 16)
                .padding(.bottom, 12)

            Divider()

            // Form content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Key name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        if isRevealed {
                            TextField("sk-...", text: $key)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("sk-...", text: $key)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(action: {
                            isRevealed.toggle()
                        }) {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding()

            // Buttons
            HStack(spacing: 10) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    onSave(name, key)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || key.isEmpty)
            }
            .padding()
            .padding(.top, 8)
        }
        .frame(width: 350)
    }
}
