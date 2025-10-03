//
//  LogoOrb.swift
//  GHOSTDeskUI
//
//  Created by Shamil on 30.09.2025.
//

import SwiftUI

public struct LogoOrb: View {
    public init() {}

    public var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor.opacity(0.7),
                            .purple.opacity(0.7),
                            .blue.opacity(0.7),
                            Color.accentColor.opacity(0.7)
                        ]),
                        center: .center
                    )
                )
                .frame(width: 36, height: 36)
                .blur(radius: 6)
                .opacity(0.6)

            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.9))
                }
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        }
    }
}
