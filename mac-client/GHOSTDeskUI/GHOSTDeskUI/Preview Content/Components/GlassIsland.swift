//
//  GlassIsland.swift
//  GHOSTDeskUI
//
//  Created by Shamil on 30.09.2025.
//

import SwiftUI

public struct GlassIsland<Content: View>: View {
    @ViewBuilder public var content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .white.opacity(0.08)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.25), radius: 28, x: 0, y: 16)
                    .shadow(color: .accentColor.opacity(0.25), radius: 40, x: 0, y: 0)
            )
    }
}
