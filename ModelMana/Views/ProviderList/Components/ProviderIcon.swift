//
//  ProviderIcon.swift
//  ModelMana
//
//  Created by refactoring from ProviderListView
//

import SwiftUI

struct ProviderIcon: View {
    let providerId: String
    let size: CGFloat

    var body: some View {
        if providerId == "zhipu" {
            Image("zhipu")
                .renderingMode(.template)
                .resizable()
                .frame(width: size, height: size)
        } else if providerId == "claude" {
            Image("claude")
                .renderingMode(.template)
                .resizable()
                .frame(width: size, height: size)
        } else if providerId == "minimax" {
            Image("minimax")
                .renderingMode(.template)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "server.rack")
                .font(.system(size: size))
        }
    }
}
