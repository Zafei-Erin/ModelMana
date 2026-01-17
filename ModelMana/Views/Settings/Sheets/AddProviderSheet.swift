//
//  AddProviderSheet.swift
//  ModelMana
//
//  Created by refactoring from SettingsWindowView
//

import SwiftUI

struct AddProviderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var baseUrl: String = ""
    let onSave: (ProviderConfig) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Add New Provider")
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
                    TextField("e.g., UniApi, Localhost", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Base URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., https://api.openai.com/v1", text: $baseUrl)
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

                Button("Add Provider") {
                    let newProvider = ProviderConfig(
                        id: UUID().uuidString,
                        name: name,
                        baseUrl: baseUrl,
                        apiKeys: []
                    )
                    onSave(newProvider)
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
