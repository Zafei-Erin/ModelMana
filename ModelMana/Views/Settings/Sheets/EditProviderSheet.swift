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
    @State private var opusModel: String
    @State private var sonnetModel: String
    @State private var haikuModel: String
    @State private var subagentModel: String
    let onSave: (ProviderConfig) -> Void

    init(provider: ProviderConfig, onSave: @escaping (ProviderConfig) -> Void) {
        self.provider = provider
        self.onSave = onSave
        self._name = State(initialValue: provider.name)
        self._baseUrl = State(initialValue: provider.baseUrl)
        self._opusModel = State(initialValue: provider.modelConfig?.opusModel ?? "")
        self._sonnetModel = State(initialValue: provider.modelConfig?.sonnetModel ?? "")
        self._haikuModel = State(initialValue: provider.modelConfig?.haikuModel ?? "")
        self._subagentModel = State(initialValue: provider.modelConfig?.subagentModel ?? "")
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
            ScrollView {
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

                    // Model Configuration
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model Configuration")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        Text("Override model names sent to Claude Code. Leave empty to use defaults.")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            modelField("Opus Model", text: $opusModel)
                            modelField("Sonnet Model", text: $sonnetModel)
                            modelField("Haiku Model", text: $haikuModel)
                            modelField("Subagent Model", text: $subagentModel)
                        }
                    }
                }
                .padding()
            }

            // Buttons
            HStack(spacing: 10) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    let mc = ModelConfig(
                        opusModel: opusModel.isEmpty ? nil : opusModel,
                        sonnetModel: sonnetModel.isEmpty ? nil : sonnetModel,
                        haikuModel: haikuModel.isEmpty ? nil : haikuModel,
                        subagentModel: subagentModel.isEmpty ? nil : subagentModel
                    )
                    let updated = ProviderConfig(
                        id: provider.id,
                        name: name,
                        baseUrl: baseUrl,
                        apiKeys: provider.apiKeys,
                        modelConfig: mc.isEmpty ? nil : mc
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
        .frame(width: 350, height: 420)
    }

    private func modelField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
        }
    }
}
