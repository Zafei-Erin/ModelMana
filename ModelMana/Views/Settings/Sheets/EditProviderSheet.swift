//
//  EditProviderSheet.swift
//  ModelMana
//
//  Created by refactoring from SettingsWindowView
//

import SwiftUI

struct EditProviderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let provider: ProviderConfig
    @State private var name: String
    @State private var baseUrl: String
    let onSave: (ProviderConfig) -> Void

    init(provider: ProviderConfig, onSave: @escaping (ProviderConfig) -> Void) {
        self.provider = provider
        self.onSave = onSave
        self._name = State(initialValue: provider.name)
        self._baseUrl = State(initialValue: provider.baseUrl)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Edit Provider")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .leading, .trailing], 16)
                .padding(.bottom, 12)

            Divider()

            // Form content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Provider Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Provider name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Base URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Base URL", text: $baseUrl)
                        .textFieldStyle(.roundedBorder)
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
                    let updated = ProviderConfig(
                        id: provider.id,
                        name: name,
                        baseUrl: baseUrl,
                        apiKeys: provider.apiKeys
                    )
                    onSave(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || baseUrl.isEmpty)
            }
            .padding()
            .padding(.top, 8)
        }
        .frame(width: 350)
    }
}
