//
//  BlackProgressStyle.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

struct BlackProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))

                    // Progress bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.black)
                        .frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0))
                }
            }
            .frame(height: 4)
        }
    }
}
